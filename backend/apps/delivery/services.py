from django.db import models, transaction
from django.utils import timezone

from apps.common.exceptions import ApplicationError
from apps.orders.models import Order, OrderStatus
from apps.orders.services import notify_order_status_change

from .models import DeliveryPartnerStatus, DeliveryShift, ShiftBooking, ShiftBookingStatus


@transaction.atomic
def accept_order(order, partner):
    if not partner.is_verified:
        raise ApplicationError("Your account is pending verification.", code="not_verified", status_code=403)
    if partner.status != DeliveryPartnerStatus.ONLINE:
        raise ApplicationError("Go online to accept deliveries.", code="not_online", status_code=400)
    if order.status != OrderStatus.READY_FOR_PICKUP or order.delivery_partner_id is not None:
        raise ApplicationError("This order is no longer available.", code="order_unavailable", status_code=400)

    order.delivery_partner = partner
    order.status = OrderStatus.OUT_FOR_DELIVERY
    order.save(update_fields=["delivery_partner", "status"])
    notify_order_status_change(order, OrderStatus.OUT_FOR_DELIVERY)

    partner.status = DeliveryPartnerStatus.ON_DELIVERY
    partner.save(update_fields=["status"])
    return order


@transaction.atomic
def mark_delivered(order, partner):
    if order.delivery_partner_id != partner.id:
        raise ApplicationError("This order is not assigned to you.", code="not_your_delivery", status_code=403)
    if order.status != OrderStatus.OUT_FOR_DELIVERY:
        raise ApplicationError(
            f'Cannot mark an order "{order.status}" as delivered.', code="invalid_transition", status_code=400
        )

    order.status = OrderStatus.DELIVERED
    order.delivered_at = timezone.now()
    # This save fires apps.delivery.signals.increment_delivery_partner_stats,
    # which atomically bumps partner.total_deliveries — don't also do it here.
    order.save(update_fields=["status", "delivered_at"])
    notify_order_status_change(order, OrderStatus.DELIVERED)

    partner.status = DeliveryPartnerStatus.ONLINE
    partner.save(update_fields=["status"])
    return order


def set_status(partner, new_status):
    partner.status = new_status
    partner.save(update_fields=["status"])
    return partner


def available_orders_queryset():
    return Order.objects.filter(status=OrderStatus.READY_FOR_PICKUP, delivery_partner__isnull=True)


def upcoming_shifts_queryset():
    now = timezone.now()
    return (
        DeliveryShift.objects.filter(date__gte=now.date())
        .annotate(booked_count=models.Count("bookings", filter=models.Q(bookings__status=ShiftBookingStatus.BOOKED)))
    )


def my_shift_bookings_queryset(partner):
    return ShiftBooking.objects.filter(
        delivery_partner=partner, status=ShiftBookingStatus.BOOKED, shift__date__gte=timezone.now().date()
    ).select_related("shift")


@transaction.atomic
def book_shift(partner, shift_id):
    shift = DeliveryShift.objects.select_for_update().filter(pk=shift_id).first()
    if shift is None:
        raise ApplicationError("This gig no longer exists.", code="shift_not_found", status_code=404)
    if shift.date < timezone.now().date():
        raise ApplicationError("This gig has already passed.", code="shift_past")

    booked_count = shift.bookings.filter(status=ShiftBookingStatus.BOOKED).exclude(delivery_partner=partner).count()
    existing = ShiftBooking.objects.filter(shift=shift, delivery_partner=partner).first()
    already_booked_by_me = existing is not None and existing.status == ShiftBookingStatus.BOOKED
    if not already_booked_by_me and booked_count >= shift.capacity:
        raise ApplicationError("This gig is full.", code="shift_full")

    # A rider can't commit to two overlapping gigs the same day.
    overlapping = (
        ShiftBooking.objects.filter(
            delivery_partner=partner, status=ShiftBookingStatus.BOOKED, shift__date=shift.date
        )
        .exclude(shift_id=shift.id)
        .filter(shift__start_time__lt=shift.end_time, shift__end_time__gt=shift.start_time)
        .exists()
    )
    if overlapping:
        raise ApplicationError("You already have another gig booked that overlaps with this time.", code="shift_overlap")

    if existing:
        existing.status = ShiftBookingStatus.BOOKED
        existing.save(update_fields=["status"])
        return existing
    return ShiftBooking.objects.create(shift=shift, delivery_partner=partner, status=ShiftBookingStatus.BOOKED)


def cancel_shift_booking(partner, shift_id):
    booking = ShiftBooking.objects.filter(
        shift_id=shift_id, delivery_partner=partner, status=ShiftBookingStatus.BOOKED
    ).first()
    if booking is None:
        raise ApplicationError("You don't have this gig booked.", code="booking_not_found", status_code=404)
    booking.status = ShiftBookingStatus.CANCELLED
    booking.save(update_fields=["status"])
    return booking

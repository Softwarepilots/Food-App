from datetime import timedelta
from decimal import Decimal

from django.conf import settings
from django.db import models, transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone

from apps.accounts.models import Address, User
from apps.common.exceptions import ApplicationError
from apps.menu.models import Food, FoodAddon, FoodVariant
from apps.menu.services import calculate_price
from apps.notifications import services as notification_services
from apps.notifications.models import NotificationType
from apps.payments.models import Payment
from apps.payments.models import PaymentMethod as PaymentMethodChoice
from apps.restaurants.models import Restaurant, RestaurantApprovalStatus

from .models import Order, OrderItem, OrderStatus, Review

FLAT_DELIVERY_FEE = Decimal("30.00")


def _restaurant_team_users(restaurant):
    """Owner + active staff — everyone on this restaurant's side who should
    hear about a new order landing."""
    staff_user_ids = restaurant.staff_members.filter(is_active=True).values_list("user_id", flat=True)
    return User.objects.filter(models.Q(pk=restaurant.owner_id) | models.Q(pk__in=staff_user_ids))


_STATUS_NOTIFICATION_COPY = {
    OrderStatus.ACCEPTED: ("Order accepted", "{restaurant} has accepted your order #{order_number}."),
    OrderStatus.PREPARING: ("Order in the kitchen", "{restaurant} has started preparing your order #{order_number}."),
    OrderStatus.READY_FOR_PICKUP: ("Ready for pickup", "Your order #{order_number} is ready and waiting for a rider."),
    OrderStatus.OUT_FOR_DELIVERY: ("On its way", "Your order #{order_number} is out for delivery."),
    OrderStatus.DELIVERED: ("Delivered", "Your order #{order_number} has been delivered. Enjoy!"),
    # Only reached via update_order_status (restaurant-initiated) — a
    # customer-initiated cancel goes through cancel_order() instead, which
    # notifies the restaurant, not the customer, since they already know.
    OrderStatus.CANCELLED: ("Order rejected", "{restaurant} was unable to accept your order #{order_number}."),
}


def notify_order_status_change(order, new_status):
    """Pushes the customer a status update. Shared between this module's
    `update_order_status` (restaurant-driven transitions) and
    apps.delivery.services (rider-driven OUT_FOR_DELIVERY/DELIVERED) so every
    status change goes through one notification path instead of each caller
    reinventing it."""
    copy = _STATUS_NOTIFICATION_COPY.get(new_status)
    if not copy:
        return
    title, body_template = copy
    notification_services.notify_user(
        order.user,
        title=title,
        body=body_template.format(restaurant=order.restaurant.name, order_number=order.order_number),
        notification_type=NotificationType.ORDER_UPDATE,
        order=order,
        data={"order_id": str(order.id), "type": f"order_{new_status}"},
    )


def _build_delivery_address_text(address):
    parts = [address.address_line1]
    if address.address_line2:
        parts.append(address.address_line2)
    parts.extend([address.city, address.state, address.pincode])
    return ", ".join(parts)


def _price_item(restaurant, item_payload):
    """Validates one cart line against the menu and returns an OrderItem-ready dict.
    Raises ApplicationError for anything that no longer matches the menu (sold out,
    wrong restaurant, invalid addon, etc.) — the client's stale cart shouldn't
    silently produce a mispriced order."""
    food = get_object_or_404(Food, pk=item_payload["food_id"], restaurant=restaurant)
    if not food.is_orderable:
        raise ApplicationError(f'"{food.name}" is currently unavailable.', code="food_unavailable")

    variant = None
    variant_id = item_payload.get("variant_id")
    if variant_id:
        variant = get_object_or_404(FoodVariant, pk=variant_id, food=food)
        if not variant.is_orderable:
            raise ApplicationError(f'"{food.name} ({variant.name})" is currently unavailable.', code="variant_unavailable")

    pricing = calculate_price(food, variant)
    quantity = item_payload["quantity"]

    addon_quantities = item_payload.get("addon_quantities") or {}
    addons_snapshot = []
    addon_unit_total = Decimal("0.00")
    for addon_id, addon_qty in addon_quantities.items():
        if not addon_qty:
            continue
        addon = get_object_or_404(FoodAddon, pk=addon_id, food=food)
        if not addon.is_available:
            raise ApplicationError(f'Add-on "{addon.name}" is currently unavailable.', code="addon_unavailable")
        if addon_qty > addon.max_quantity:
            raise ApplicationError(f'"{addon.name}" allows at most {addon.max_quantity} per item.', code="addon_limit")
        addons_snapshot.append({"id": str(addon.id), "name": addon.name, "price": str(addon.price), "quantity": addon_qty})
        addon_unit_total += addon.price * addon_qty

    unit_total = pricing["final_price"] + addon_unit_total
    line_total = (unit_total * quantity).quantize(Decimal("0.01"))

    return {
        "food": food,
        "variant": variant,
        "food_name_snapshot": food.name,
        "variant_name_snapshot": variant.name if variant else "",
        "unit_price_snapshot": pricing["final_price"],
        "quantity": quantity,
        "addons_snapshot": addons_snapshot,
        "line_total": line_total,
        "notes": item_payload.get("notes") or "",
    }


@transaction.atomic
def place_order(user, *, restaurant_id, address_id, items_payload, payment_method, notes=""):
    if not items_payload:
        raise ApplicationError("Your cart is empty.", code="empty_cart")

    restaurant = get_object_or_404(Restaurant, pk=restaurant_id)
    if restaurant.approval_status != RestaurantApprovalStatus.APPROVED or not restaurant.is_active:
        raise ApplicationError("This restaurant is not currently accepting orders.", code="restaurant_unavailable")
    if not restaurant.is_orderable:
        raise ApplicationError("This restaurant is closed right now.", code="restaurant_closed")

    address = get_object_or_404(Address, pk=address_id, user=user)

    priced_items = [_price_item(restaurant, item) for item in items_payload]
    subtotal = sum((item["line_total"] for item in priced_items), Decimal("0.00"))
    delivery_fee = FLAT_DELIVERY_FEE
    tax_amount = Decimal("0.00")  # GST is already priced into each item's unit price.
    discount_amount = Decimal("0.00")
    total_amount = subtotal + delivery_fee + tax_amount - discount_amount

    order = Order.objects.create(
        user=user,
        restaurant=restaurant,
        delivery_address_text=_build_delivery_address_text(address),
        delivery_latitude=address.latitude,
        delivery_longitude=address.longitude,
        notes=notes,
        subtotal=subtotal,
        delivery_fee=delivery_fee,
        tax_amount=tax_amount,
        discount_amount=discount_amount,
        total_amount=total_amount,
        accept_deadline=timezone.now() + timedelta(seconds=settings.ORDER_ACCEPT_TIMEOUT_SECONDS),
    )

    for item in priced_items:
        OrderItem.objects.create(order=order, **item)

    payment_method_value = (
        PaymentMethodChoice.COD if payment_method == "cod" else PaymentMethodChoice.RAZORPAY
    )
    Payment.objects.create(order=order, method=payment_method_value, amount=total_amount)

    notification_services.notify_users(
        _restaurant_team_users(restaurant),
        title="New order received",
        body=f"Order #{order.order_number} just came in — {len(priced_items)} item(s).",
        notification_type=NotificationType.ORDER_UPDATE,
        order=order,
        data={"order_id": str(order.id), "type": "new_order"},
    )

    return order


def auto_reject_expired_orders(queryset=None):
    """Lazy-expiry sweep (no Celery/cron): transitions any still-PLACED order
    past its `accept_deadline` to CANCELLED. Reuses the existing CANCELLED
    status rather than adding a new AUTO_REJECTED enum value, since neither
    Flutter app's OrderStatus enum knows about one — this keeps the change
    backward-compatible at the cost of not distinguishing "restaurant
    rejected" from "restaurant never responded" in the status itself (the
    cancellation_reason still records which happened).
    Called opportunistically from order list/detail views before serializing,
    same pattern as Restaurant.is_paused_now."""
    base = queryset if queryset is not None else Order.objects.all()
    expired = list(base.filter(status=OrderStatus.PLACED, accept_deadline__lt=timezone.now()).select_related("user"))
    if not expired:
        return
    now = timezone.now()
    for order in expired:
        order.status = OrderStatus.CANCELLED
        order.cancellation_reason = "Auto-rejected: restaurant did not respond in time."
        order.cancelled_at = now
    Order.objects.bulk_update(expired, ["status", "cancellation_reason", "cancelled_at"])
    for order in expired:
        notification_services.notify_user(
            order.user,
            title="Order cancelled",
            body=f"Sorry — order #{order.order_number} wasn't accepted in time and was cancelled.",
            notification_type=NotificationType.ORDER_UPDATE,
            order=order,
            data={"order_id": str(order.id), "type": "order_auto_rejected"},
        )


def cancel_order(order, user, reason=""):
    if order.user_id != user.id:
        raise ApplicationError("You can only cancel your own orders.", code="not_your_order", status_code=403)
    if order.status not in (OrderStatus.PLACED, OrderStatus.ACCEPTED):
        raise ApplicationError("This order can no longer be cancelled.", code="cannot_cancel")

    order.status = OrderStatus.CANCELLED
    order.cancellation_reason = reason
    order.cancelled_at = timezone.now()
    order.save(update_fields=["status", "cancellation_reason", "cancelled_at"])

    notification_services.notify_users(
        _restaurant_team_users(order.restaurant),
        title="Order cancelled",
        body=f"The customer cancelled order #{order.order_number}.",
        notification_type=NotificationType.ORDER_UPDATE,
        order=order,
        data={"order_id": str(order.id), "type": "order_cancelled_by_customer"},
    )
    return order


# Restaurant-partner-facing status transitions. Each key's forward moves are
# the only next states the owner app is allowed to set — anything else
# (skipping a stage, moving backwards) is rejected. Once an order is ready for
# pickup, ownership of the remaining transitions (claim -> deliver) moves to
# the delivery partner app — see apps.delivery.services.
ALLOWED_STATUS_TRANSITIONS = {
    OrderStatus.PLACED: {OrderStatus.ACCEPTED, OrderStatus.CANCELLED},
    OrderStatus.ACCEPTED: {OrderStatus.PREPARING, OrderStatus.CANCELLED},
    OrderStatus.PREPARING: {OrderStatus.READY_FOR_PICKUP},
}


def update_order_status(order, new_status, *, prep_time_minutes=None):
    allowed = ALLOWED_STATUS_TRANSITIONS.get(order.status, set())
    if new_status not in allowed:
        raise ApplicationError(
            f'Cannot move an order from "{order.status}" to "{new_status}".', code="invalid_transition"
        )

    order.status = new_status
    now = timezone.now()
    update_fields = ["status"]
    if new_status == OrderStatus.ACCEPTED:
        order.accepted_at = now
        order.estimated_prep_minutes = prep_time_minutes
        update_fields += ["accepted_at", "estimated_prep_minutes"]
    elif new_status == OrderStatus.DELIVERED:
        order.delivered_at = now
        update_fields.append("delivered_at")
    elif new_status == OrderStatus.CANCELLED:
        order.cancelled_at = now
        update_fields.append("cancelled_at")
    order.save(update_fields=update_fields)
    notify_order_status_change(order, new_status)
    return order


def submit_review(order, user, *, rating, comment="", delivery_rating=None):
    """One review per order — resubmitting updates it (matches the
    `unique_review_per_order` constraint), same pattern as FoodReview."""
    if order.user_id != user.id:
        raise ApplicationError("You can only review your own orders.", code="not_your_order", status_code=403)
    if order.status != OrderStatus.DELIVERED:
        raise ApplicationError("You can only review an order after it's delivered.", code="order_not_delivered")

    # A rider rating only makes sense if this order actually had one — silently
    # drop it rather than erroring, since the client can't always know in
    # advance whether a delivery partner was assigned.
    has_delivery_partner = order.delivery_partner_id is not None
    review, created = Review.objects.update_or_create(
        user=user,
        order=order,
        defaults={
            "restaurant": order.restaurant,
            "rating": rating,
            "comment": comment,
            "delivery_partner_id": order.delivery_partner_id if has_delivery_partner else None,
            "delivery_rating": delivery_rating if has_delivery_partner else None,
        },
    )

    notification_services.notify_users(
        _restaurant_team_users(order.restaurant),
        title="New review",
        body=f"{user.full_name} left a {rating}★ review for order #{order.order_number}.",
        notification_type=NotificationType.ORDER_UPDATE,
        order=order,
        data={"order_id": str(order.id), "type": "new_review"},
    )
    if has_delivery_partner and review.delivery_rating is not None:
        notification_services.notify_user(
            order.delivery_partner.user,
            title="New delivery review",
            body=f"{user.full_name} rated your delivery {review.delivery_rating}★ for order #{order.order_number}.",
            notification_type=NotificationType.ORDER_UPDATE,
            order=order,
            data={"order_id": str(order.id), "type": "new_delivery_review"},
        )

    return review, created

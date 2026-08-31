from decimal import Decimal

from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone

from apps.accounts.models import Address
from apps.common.exceptions import ApplicationError
from apps.menu.models import Food, FoodAddon, FoodVariant
from apps.menu.services import calculate_price
from apps.payments import services as payments_services
from apps.payments.models import PaymentMethod as PaymentMethodChoice
from apps.restaurants.models import Restaurant, RestaurantApprovalStatus

from .models import Order, OrderItem, OrderStatus

FLAT_DELIVERY_FEE = Decimal("30.00")


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
    )

    for item in priced_items:
        OrderItem.objects.create(order=order, **item)

    payment_method_value = (
        PaymentMethodChoice.COD if payment_method == "cod" else PaymentMethodChoice.RAZORPAY
    )
    payments_services.create_payment_for_order(order, method=payment_method_value, amount=total_amount)

    return order


def cancel_order(order, user, reason=""):
    if order.user_id != user.id:
        raise ApplicationError("You can only cancel your own orders.", code="not_your_order", status_code=403)
    if order.status not in (OrderStatus.PLACED, OrderStatus.ACCEPTED):
        raise ApplicationError("This order can no longer be cancelled.", code="cannot_cancel")

    order.status = OrderStatus.CANCELLED
    order.cancellation_reason = reason
    order.cancelled_at = timezone.now()
    order.save(update_fields=["status", "cancellation_reason", "cancelled_at"])
    return order


# Restaurant-partner-facing and delivery-partner-facing status transitions.
# Each key's forward moves are the only next states allowed — anything else
# (skipping a stage, moving backwards) is rejected. Callers outside this app
# (e.g. apps.delivery.services) go through update_order_status/
# assign_delivery_partner below rather than mutating Order directly, so this
# module stays the single place order-state rules are enforced.
ALLOWED_STATUS_TRANSITIONS = {
    OrderStatus.PLACED: {OrderStatus.ACCEPTED, OrderStatus.CANCELLED},
    OrderStatus.ACCEPTED: {OrderStatus.PREPARING, OrderStatus.CANCELLED},
    OrderStatus.PREPARING: {OrderStatus.READY_FOR_PICKUP},
    OrderStatus.OUT_FOR_DELIVERY: {OrderStatus.DELIVERED},
}


def update_order_status(order, new_status):
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
        update_fields.append("accepted_at")
    elif new_status == OrderStatus.DELIVERED:
        order.delivered_at = now
        update_fields.append("delivered_at")
    elif new_status == OrderStatus.CANCELLED:
        order.cancelled_at = now
        update_fields.append("cancelled_at")
    order.save(update_fields=update_fields)
    return order


def assign_delivery_partner(order, delivery_partner):
    """Claims a ready-for-pickup order for a delivery partner. Owned here
    (not in apps.delivery) because it mutates Order's own state machine —
    apps.delivery.services.accept_order calls this after its own
    partner-eligibility checks."""
    if order.status != OrderStatus.READY_FOR_PICKUP or order.delivery_partner_id is not None:
        raise ApplicationError("This order is no longer available.", code="order_unavailable", status_code=400)

    order.delivery_partner = delivery_partner
    order.status = OrderStatus.OUT_FOR_DELIVERY
    order.save(update_fields=["delivery_partner", "status"])
    return order


def set_payment_status(order_id, new_payment_status):
    """Used by apps.payments.signals when a Payment's gateway status changes.
    Deliberately a queryset .update() rather than fetch+save so this does not
    fire Order's post_save signals on every payment-status sync."""
    Order.objects.filter(pk=order_id).exclude(payment_status=new_payment_status).update(
        payment_status=new_payment_status
    )

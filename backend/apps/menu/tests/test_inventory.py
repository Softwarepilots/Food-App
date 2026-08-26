from decimal import Decimal

import pytest

pytestmark = pytest.mark.django_db


def _availability_url(restaurant_id, food_id):
    return f"/api/v1/menu/restaurants/{restaurant_id}/foods/{food_id}/availability/"


def _inventory_url(restaurant_id, food_id):
    return f"/api/v1/menu/restaurants/{restaurant_id}/foods/{food_id}/inventory/"


def _make_order_item(food, quantity, variant=None):
    from apps.orders.models import Order, OrderItem

    order = Order.objects.create(
        user=food.restaurant.owner,  # any existing user works for this signal-focused test
        restaurant=food.restaurant,
        delivery_address_text="123 Somewhere",
        delivery_latitude=Decimal("13.0827"),
        delivery_longitude=Decimal("80.2707"),
        subtotal=Decimal("100.00"),
        total_amount=Decimal("100.00"),
    )
    return OrderItem.objects.create(
        order=order,
        food=food,
        variant=variant,
        food_name_snapshot=food.name,
        unit_price_snapshot=food.base_price,
        quantity=quantity,
        line_total=food.base_price * quantity,
    )


def test_owner_can_toggle_availability(api_client, make_food, owner_user, auth_header):
    food = make_food(is_available=True)

    response = api_client.patch(
        _availability_url(food.restaurant_id, food.id), {"is_available": False}, format="json",
        HTTP_AUTHORIZATION=auth_header(owner_user),
    )

    assert response.status_code == 200
    assert response.json()["data"]["is_available"] is False


def test_other_owner_cannot_toggle_availability(api_client, make_food, other_owner_user, auth_header):
    food = make_food()

    response = api_client.patch(
        _availability_url(food.restaurant_id, food.id), {"is_available": False}, format="json",
        HTTP_AUTHORIZATION=auth_header(other_owner_user),
    )

    assert response.status_code == 403


def test_owner_can_enable_inventory_tracking(api_client, make_food, owner_user, auth_header):
    food = make_food()

    response = api_client.patch(
        _inventory_url(food.restaurant_id, food.id),
        {"track_inventory": True, "stock_quantity": 20, "low_stock_threshold": 5},
        format="json",
        HTTP_AUTHORIZATION=auth_header(owner_user),
    )

    assert response.status_code == 200
    food.refresh_from_db()
    assert food.track_inventory is True
    assert food.stock_quantity == 20


def test_order_item_decrements_food_stock(make_food):
    food = make_food(track_inventory=True, stock_quantity=10)

    _make_order_item(food, quantity=3)

    food.refresh_from_db()
    assert food.stock_quantity == 7
    assert food.is_available is True


def test_stock_reaching_zero_auto_hides_food(make_food):
    food = make_food(track_inventory=True, stock_quantity=3)

    _make_order_item(food, quantity=3)

    food.refresh_from_db()
    assert food.stock_quantity == 0
    assert food.is_available is False


def test_stock_reaching_zero_notifies_owner(make_food):
    from apps.notifications.models import Notification

    food = make_food(track_inventory=True, stock_quantity=2)

    _make_order_item(food, quantity=2)

    assert Notification.objects.filter(
        user=food.restaurant.owner, title="Inventory alert", body__icontains="out of stock"
    ).exists()


def test_low_stock_notifies_owner_without_hiding(make_food):
    from apps.notifications.models import Notification

    food = make_food(track_inventory=True, stock_quantity=10, low_stock_threshold=5)

    _make_order_item(food, quantity=6)

    food.refresh_from_db()
    assert food.stock_quantity == 4
    assert food.is_available is True
    assert Notification.objects.filter(
        user=food.restaurant.owner, title="Inventory alert", body__icontains="running low"
    ).exists()


def test_untracked_food_stock_unaffected_by_orders(make_food):
    food = make_food(track_inventory=False, stock_quantity=0)

    _make_order_item(food, quantity=5)

    food.refresh_from_db()
    assert food.stock_quantity == 0
    assert food.is_available is True


def test_variant_stock_decrements_independently(make_food):
    from apps.menu.models import FoodVariant

    food = make_food(track_inventory=False)
    variant = FoodVariant.objects.create(
        food=food, name="Full", price=Decimal("150.00"), track_inventory=True, stock_quantity=5
    )

    _make_order_item(food, quantity=2, variant=variant)

    variant.refresh_from_db()
    food.refresh_from_db()
    assert variant.stock_quantity == 3
    assert food.stock_quantity == 0  # untouched/untracked, still default

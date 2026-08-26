import pytest

pytestmark = pytest.mark.django_db


def _list_url(restaurant_id):
    return f"/api/v1/menu/restaurants/{restaurant_id}/foods/"


def _detail_url(restaurant_id, pk):
    return f"/api/v1/menu/restaurants/{restaurant_id}/foods/{pk}/"


def test_owner_can_create_food(api_client, make_restaurant, owner_user, auth_header):
    restaurant = make_restaurant(owner=owner_user)

    response = api_client.post(
        _list_url(restaurant.id),
        {"name": "Paneer Tikka", "base_price": "180.00", "gst_rate": "5.00"},
        format="json",
        HTTP_AUTHORIZATION=auth_header(owner_user),
    )

    assert response.status_code == 201
    assert response.json()["data"]["name"] == "Paneer Tikka"


def test_invalid_gst_rate_rejected(api_client, make_restaurant, owner_user, auth_header):
    restaurant = make_restaurant(owner=owner_user)

    response = api_client.post(
        _list_url(restaurant.id),
        {"name": "Paneer Tikka", "base_price": "180.00", "gst_rate": "13.50"},
        format="json",
        HTTP_AUTHORIZATION=auth_header(owner_user),
    )

    assert response.status_code == 400


def test_food_list_requires_ownership(api_client, make_restaurant, other_owner_user, auth_header):
    restaurant = make_restaurant()

    response = api_client.get(_list_url(restaurant.id), HTTP_AUTHORIZATION=auth_header(other_owner_user))

    assert response.status_code == 403


def test_food_list_shows_unavailable_items_to_owner(api_client, make_food, owner_user, auth_header):
    restaurant = make_food(is_available=True).restaurant
    make_food(restaurant=restaurant, name="Hidden Item", is_available=False)

    response = api_client.get(_list_url(restaurant.id), HTTP_AUTHORIZATION=auth_header(owner_user))

    names = {f["name"] for f in response.json()["data"]}
    assert "Hidden Item" in names


def test_category_must_belong_to_same_restaurant(api_client, make_restaurant, owner_user, auth_header):
    from apps.menu.models import FoodCategory

    restaurant = make_restaurant(owner=owner_user)
    other_restaurant = make_restaurant(name="Other Place")
    foreign_category = FoodCategory.objects.create(restaurant=other_restaurant, name="Mains")

    response = api_client.post(
        _list_url(restaurant.id),
        {"name": "Dish", "base_price": "100.00", "category": str(foreign_category.id)},
        format="json",
        HTTP_AUTHORIZATION=auth_header(owner_user),
    )

    assert response.status_code == 400


def test_owner_can_update_and_delete_food(api_client, make_food, owner_user, auth_header):
    food = make_food()
    header = auth_header(owner_user)

    update_response = api_client.patch(
        _detail_url(food.restaurant_id, food.id), {"name": "Updated Name"}, format="json", HTTP_AUTHORIZATION=header
    )
    delete_response = api_client.delete(_detail_url(food.restaurant_id, food.id), HTTP_AUTHORIZATION=header)

    assert update_response.status_code == 200
    assert update_response.json()["data"]["name"] == "Updated Name"
    assert delete_response.status_code == 204


def test_public_can_view_available_food_detail(api_client, make_food):
    food = make_food()

    response = api_client.get(_detail_url(food.restaurant_id, food.id))

    assert response.status_code == 200

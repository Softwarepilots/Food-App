import pytest

pytestmark = pytest.mark.django_db


def _menu_url(restaurant_id):
    return f"/api/v1/menu/restaurants/{restaurant_id}/menu/"


def test_public_menu_groups_foods_by_category(api_client, make_restaurant, make_food):
    from apps.menu.models import FoodCategory

    restaurant = make_restaurant()
    category = FoodCategory.objects.create(restaurant=restaurant, name="Mains")
    make_food(restaurant=restaurant, name="Biryani", category=category)
    make_food(restaurant=restaurant, name="Uncategorized Dish")

    response = api_client.get(_menu_url(restaurant.id))

    assert response.status_code == 200
    body = response.json()["data"]
    assert body["categories"][0]["name"] == "Mains"
    assert body["categories"][0]["foods"][0]["name"] == "Biryani"
    assert any(f["name"] == "Uncategorized Dish" for f in body["uncategorized"])


def test_public_menu_hides_unavailable_food(api_client, make_restaurant, make_food):
    from apps.menu.models import FoodCategory

    restaurant = make_restaurant()
    category = FoodCategory.objects.create(restaurant=restaurant, name="Mains")
    make_food(restaurant=restaurant, name="Visible Dish", category=category, is_available=True)
    make_food(restaurant=restaurant, name="Hidden Dish", category=category, is_available=False)

    response = api_client.get(_menu_url(restaurant.id))

    names = {f["name"] for f in response.json()["data"]["categories"][0]["foods"]}
    assert names == {"Visible Dish"}


def test_public_menu_includes_pricing_breakdown(api_client, make_restaurant, make_food):
    from apps.menu.models import FoodCategory

    restaurant = make_restaurant()
    category = FoodCategory.objects.create(restaurant=restaurant, name="Mains")
    make_food(restaurant=restaurant, name="Biryani", category=category, base_price="200.00", gst_rate="5.00")

    response = api_client.get(_menu_url(restaurant.id))

    food = response.json()["data"]["categories"][0]["foods"][0]
    assert food["pricing"]["final_price"] == "210.00"


def test_public_menu_404s_for_unapproved_restaurant(api_client, make_restaurant):
    restaurant = make_restaurant(approval_status="pending")

    response = api_client.get(_menu_url(restaurant.id))

    assert response.status_code == 404

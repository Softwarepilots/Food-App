import pytest

pytestmark = pytest.mark.django_db

CATEGORY_LIST_URL = "/api/v1/restaurants/categories/"


def _detail_url(pk):
    return f"/api/v1/restaurants/categories/{pk}/"


def test_public_can_list_active_categories(api_client):
    from apps.restaurants.models import RestaurantCategory

    RestaurantCategory.objects.create(name="Fast Food", is_active=True)
    RestaurantCategory.objects.create(name="Disabled Category", is_active=False)

    response = api_client.get(CATEGORY_LIST_URL)

    assert response.status_code == 200
    names = {c["name"] for c in response.json()["data"]}
    assert names == {"Fast Food"}


def test_create_category_requires_admin(api_client, owner_user, auth_header):
    response = api_client.post(
        CATEGORY_LIST_URL, {"name": "Cafe"}, format="json", HTTP_AUTHORIZATION=auth_header(owner_user)
    )

    assert response.status_code == 403


def test_admin_can_create_and_update_category(api_client, admin_user, auth_header):
    create_response = api_client.post(
        CATEGORY_LIST_URL, {"name": "Cafe"}, format="json", HTTP_AUTHORIZATION=auth_header(admin_user)
    )
    assert create_response.status_code == 201
    category_id = create_response.json()["data"]["id"]
    assert create_response.json()["data"]["slug"] == "cafe"

    update_response = api_client.patch(
        _detail_url(category_id), {"is_active": False}, format="json", HTTP_AUTHORIZATION=auth_header(admin_user)
    )
    assert update_response.status_code == 200
    assert update_response.json()["data"]["is_active"] is False


def test_assign_categories_to_restaurant(api_client, make_restaurant, owner_user, auth_header):
    from apps.restaurants.models import RestaurantCategory

    category = RestaurantCategory.objects.create(name="Fine Dining")
    restaurant = make_restaurant(owner=owner_user)

    response = api_client.patch(
        f"/api/v1/restaurants/{restaurant.id}/",
        {"category_ids": [str(category.id)]},
        format="json",
        HTTP_AUTHORIZATION=auth_header(owner_user),
    )

    assert response.status_code == 200
    assert response.json()["data"]["categories"][0]["name"] == "Fine Dining"

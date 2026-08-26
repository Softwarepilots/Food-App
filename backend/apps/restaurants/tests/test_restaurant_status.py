import pytest

pytestmark = pytest.mark.django_db


def _status_url(pk):
    return f"/api/v1/restaurants/{pk}/status/"


def _detail_url(pk):
    return f"/api/v1/restaurants/{pk}/"


def test_owner_can_pause_accepting_orders(api_client, make_restaurant, owner_user, auth_header):
    restaurant = make_restaurant(owner=owner_user)

    response = api_client.patch(
        _status_url(restaurant.id), {"is_accepting_orders": False}, format="json", HTTP_AUTHORIZATION=auth_header(owner_user)
    )

    assert response.status_code == 200
    restaurant.refresh_from_db()
    assert restaurant.is_accepting_orders is False
    assert response.json()["data"]["display_status"] == "paused"


def test_other_owner_cannot_toggle_status(api_client, make_restaurant, other_owner_user, auth_header):
    restaurant = make_restaurant()

    response = api_client.patch(
        _status_url(restaurant.id), {"is_active": False}, format="json", HTTP_AUTHORIZATION=auth_header(other_owner_user)
    )

    assert response.status_code == 403


def test_display_status_pending_for_unapproved_restaurant(api_client, make_restaurant, owner_user, auth_header):
    restaurant = make_restaurant(owner=owner_user, approval_status="pending")

    response = api_client.get(_detail_url(restaurant.id), HTTP_AUTHORIZATION=auth_header(owner_user))

    assert response.json()["data"]["display_status"] == "pending"


def test_display_status_open_for_approved_active_restaurant(api_client, make_restaurant):
    restaurant = make_restaurant()

    response = api_client.get(_detail_url(restaurant.id))

    assert response.json()["data"]["display_status"] == "open"

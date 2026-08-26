import pytest

pytestmark = pytest.mark.django_db

LIST_CREATE_URL = "/api/v1/restaurants/"
MINE_URL = "/api/v1/restaurants/mine/"


def _detail_url(pk):
    return f"/api/v1/restaurants/{pk}/"


def test_public_list_only_shows_approved_active_restaurants(api_client, make_restaurant):
    approved = make_restaurant(name="Approved Place", approval_status="approved", is_active=True)
    make_restaurant(name="Pending Place", approval_status="pending", is_active=True)
    make_restaurant(name="Inactive Place", approval_status="approved", is_active=False)

    response = api_client.get(LIST_CREATE_URL)

    assert response.status_code == 200
    names = {r["name"] for r in response.json()["data"]}
    assert names == {approved.name}


def test_public_detail_404s_for_pending_restaurant(api_client, make_restaurant):
    restaurant = make_restaurant(approval_status="pending")

    response = api_client.get(_detail_url(restaurant.id))

    assert response.status_code == 404


def test_owner_can_view_own_pending_restaurant(api_client, make_restaurant, owner_user, auth_header):
    restaurant = make_restaurant(owner=owner_user, approval_status="pending")

    response = api_client.get(_detail_url(restaurant.id), HTTP_AUTHORIZATION=auth_header(owner_user))

    assert response.status_code == 200


def test_create_restaurant_requires_restaurant_owner_role(api_client, customer_user, auth_header):
    payload = {
        "name": "New Place", "address_line": "1 Main St", "city": "Chennai",
        "latitude": "13.0827", "longitude": "80.2707",
    }
    response = api_client.post(LIST_CREATE_URL, payload, format="json", HTTP_AUTHORIZATION=auth_header(customer_user))

    assert response.status_code == 403


def test_create_restaurant_starts_pending_approval(api_client, owner_user, auth_header):
    payload = {
        "name": "New Place", "address_line": "1 Main St", "city": "Chennai",
        "latitude": "13.0827", "longitude": "80.2707",
    }
    response = api_client.post(LIST_CREATE_URL, payload, format="json", HTTP_AUTHORIZATION=auth_header(owner_user))

    assert response.status_code == 201
    body = response.json()["data"]
    assert body["approval_status"] == "pending"
    assert body["owner"] == str(owner_user.id)


def test_owner_sees_all_own_restaurants_regardless_of_status(api_client, make_restaurant, owner_user, auth_header):
    make_restaurant(owner=owner_user, name="Approved", approval_status="approved")
    make_restaurant(owner=owner_user, name="Pending", approval_status="pending")

    response = api_client.get(MINE_URL, HTTP_AUTHORIZATION=auth_header(owner_user))

    assert response.status_code == 200
    names = {r["name"] for r in response.json()["data"]}
    assert names == {"Approved", "Pending"}


def test_owner_cannot_update_another_owners_restaurant(api_client, make_restaurant, other_owner_user, auth_header):
    restaurant = make_restaurant()

    response = api_client.patch(
        _detail_url(restaurant.id), {"name": "Hijacked"}, format="json", HTTP_AUTHORIZATION=auth_header(other_owner_user)
    )

    assert response.status_code == 403


def test_owner_update_cannot_set_approval_status(api_client, make_restaurant, owner_user, auth_header):
    restaurant = make_restaurant(owner=owner_user, approval_status="pending")

    response = api_client.patch(
        _detail_url(restaurant.id),
        {"name": "Updated Name", "approval_status": "approved"},
        format="json",
        HTTP_AUTHORIZATION=auth_header(owner_user),
    )

    assert response.status_code == 200
    restaurant.refresh_from_db()
    assert restaurant.name == "Updated Name"
    assert restaurant.approval_status == "pending"


def test_owner_can_soft_delete_own_restaurant(api_client, make_restaurant, owner_user, auth_header):
    restaurant = make_restaurant(owner=owner_user)

    response = api_client.delete(_detail_url(restaurant.id), HTTP_AUTHORIZATION=auth_header(owner_user))

    assert response.status_code == 204
    restaurant.refresh_from_db()
    assert restaurant.is_deleted is True


def test_admin_can_view_and_delete_any_restaurant(api_client, make_restaurant, admin_user, auth_header):
    restaurant = make_restaurant(approval_status="pending")

    get_response = api_client.get(_detail_url(restaurant.id), HTTP_AUTHORIZATION=auth_header(admin_user))
    delete_response = api_client.delete(_detail_url(restaurant.id), HTTP_AUTHORIZATION=auth_header(admin_user))

    assert get_response.status_code == 200
    assert delete_response.status_code == 204

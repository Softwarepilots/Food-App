import pytest

pytestmark = pytest.mark.django_db

PENDING_URL = "/api/v1/restaurants/pending-approval/"


def _approve_url(pk):
    return f"/api/v1/restaurants/{pk}/approve/"


def _reject_url(pk):
    return f"/api/v1/restaurants/{pk}/reject/"


def test_pending_approval_list_requires_admin(api_client, owner_user, auth_header):
    response = api_client.get(PENDING_URL, HTTP_AUTHORIZATION=auth_header(owner_user))

    assert response.status_code == 403


def test_pending_approval_list_shows_only_pending(api_client, make_restaurant, admin_user, auth_header):
    pending = make_restaurant(name="Pending One", approval_status="pending")
    make_restaurant(name="Already Approved", approval_status="approved")

    response = api_client.get(PENDING_URL, HTTP_AUTHORIZATION=auth_header(admin_user))

    assert response.status_code == 200
    names = {r["name"] for r in response.json()["data"]}
    assert names == {pending.name}


def test_approve_restaurant(api_client, make_restaurant, admin_user, auth_header, mailoutbox):
    restaurant = make_restaurant(approval_status="pending")

    response = api_client.post(_approve_url(restaurant.id), {}, format="json", HTTP_AUTHORIZATION=auth_header(admin_user))

    assert response.status_code == 200
    restaurant.refresh_from_db()
    assert restaurant.approval_status == "approved"
    assert restaurant.approved_by_id == admin_user.id
    assert restaurant.approved_at is not None


def test_approve_restaurant_notifies_owner(api_client, make_restaurant, owner_user, admin_user, auth_header):
    from apps.notifications.models import Notification

    restaurant = make_restaurant(owner=owner_user, approval_status="pending")

    api_client.post(_approve_url(restaurant.id), {}, format="json", HTTP_AUTHORIZATION=auth_header(admin_user))

    assert Notification.objects.filter(user=owner_user, title__icontains="approval").exists()


def test_reject_restaurant_requires_reason(api_client, make_restaurant, admin_user, auth_header):
    restaurant = make_restaurant(approval_status="pending")

    response = api_client.post(_reject_url(restaurant.id), {}, format="json", HTTP_AUTHORIZATION=auth_header(admin_user))

    assert response.status_code == 400


def test_reject_restaurant(api_client, make_restaurant, admin_user, auth_header):
    restaurant = make_restaurant(approval_status="pending")

    response = api_client.post(
        _reject_url(restaurant.id), {"reason": "Missing documents"}, format="json", HTTP_AUTHORIZATION=auth_header(admin_user)
    )

    assert response.status_code == 200
    restaurant.refresh_from_db()
    assert restaurant.approval_status == "rejected"
    assert restaurant.rejection_reason == "Missing documents"


def test_owner_cannot_approve_own_restaurant(api_client, make_restaurant, owner_user, auth_header):
    restaurant = make_restaurant(owner=owner_user, approval_status="pending")

    response = api_client.post(_approve_url(restaurant.id), {}, format="json", HTTP_AUTHORIZATION=auth_header(owner_user))

    assert response.status_code == 403

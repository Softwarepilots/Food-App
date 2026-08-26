import pytest

pytestmark = pytest.mark.django_db


def _hours_url(pk):
    return f"/api/v1/restaurants/{pk}/business-hours/"


def test_get_business_hours_public(api_client, make_restaurant):
    restaurant = make_restaurant()

    response = api_client.get(_hours_url(restaurant.id))

    assert response.status_code == 200
    assert len(response.json()["data"]) == 7


def test_owner_can_replace_business_hours(api_client, make_restaurant, owner_user, auth_header):
    restaurant = make_restaurant(owner=owner_user)
    entries = [
        {"day_of_week": day, "opening_time": "09:00", "closing_time": "22:00", "is_closed": False}
        for day in range(6)
    ] + [{"day_of_week": 6, "opening_time": None, "closing_time": None, "is_closed": True}]

    response = api_client.put(
        _hours_url(restaurant.id), {"entries": entries}, format="json", HTTP_AUTHORIZATION=auth_header(owner_user)
    )

    assert response.status_code == 200
    data = response.json()["data"]
    assert len(data) == 7
    sunday = next(e for e in data if e["day_of_week"] == 6)
    assert sunday["is_closed"] is True


def test_business_hours_rejects_duplicate_day(api_client, make_restaurant, owner_user, auth_header):
    restaurant = make_restaurant(owner=owner_user)
    entries = [
        {"day_of_week": 0, "opening_time": "09:00", "closing_time": "22:00", "is_closed": False},
        {"day_of_week": 0, "opening_time": "10:00", "closing_time": "23:00", "is_closed": False},
    ]

    response = api_client.put(
        _hours_url(restaurant.id), {"entries": entries}, format="json", HTTP_AUTHORIZATION=auth_header(owner_user)
    )

    assert response.status_code == 400


def test_business_hours_requires_times_unless_closed(api_client, make_restaurant, owner_user, auth_header):
    restaurant = make_restaurant(owner=owner_user)
    entries = [{"day_of_week": 0, "is_closed": False}]

    response = api_client.put(
        _hours_url(restaurant.id), {"entries": entries}, format="json", HTTP_AUTHORIZATION=auth_header(owner_user)
    )

    assert response.status_code == 400


def test_other_owner_cannot_replace_business_hours(api_client, make_restaurant, other_owner_user, auth_header):
    restaurant = make_restaurant()

    response = api_client.put(
        _hours_url(restaurant.id), {"entries": []}, format="json", HTTP_AUTHORIZATION=auth_header(other_owner_user)
    )

    assert response.status_code == 403


def test_restaurant_closed_when_outside_business_hours(api_client, make_restaurant, owner_user, auth_header):
    from datetime import time

    from django.utils import timezone

    restaurant = make_restaurant(owner=owner_user)
    current_weekday = timezone.localtime().weekday()
    # Set today to closed, and give an explicit closing time in the past for clarity.
    restaurant.business_hours.filter(day_of_week=current_weekday).update(
        is_closed=True, opening_time=time(0, 0), closing_time=time(0, 1)
    )

    response = api_client.get(f"/api/v1/restaurants/{restaurant.id}/", HTTP_AUTHORIZATION=auth_header(owner_user))

    assert response.json()["data"]["is_open_now"] is False

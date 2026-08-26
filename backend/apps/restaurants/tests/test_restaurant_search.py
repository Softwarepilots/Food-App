from decimal import Decimal

import pytest

pytestmark = pytest.mark.django_db

LIST_URL = "/api/v1/restaurants/"


def test_filter_by_city(api_client, make_restaurant):
    make_restaurant(name="Chennai Place", city="Chennai")
    make_restaurant(name="Mumbai Place", city="Mumbai")

    response = api_client.get(LIST_URL, {"city": "Mumbai"})

    names = {r["name"] for r in response.json()["data"]}
    assert names == {"Mumbai Place"}


def test_filter_by_cuisine_tag(api_client, make_restaurant):
    make_restaurant(name="Pizza Place", cuisine_tags=["Italian", "Pizza"])
    make_restaurant(name="Sushi Place", cuisine_tags=["Japanese"])

    response = api_client.get(LIST_URL, {"cuisine": "italian"})

    names = {r["name"] for r in response.json()["data"]}
    assert names == {"Pizza Place"}


def test_filter_by_search_name(api_client, make_restaurant):
    make_restaurant(name="Tasty Bites")
    make_restaurant(name="Quick Eats")

    response = api_client.get(LIST_URL, {"search": "tasty"})

    names = {r["name"] for r in response.json()["data"]}
    assert names == {"Tasty Bites"}


def test_filter_by_delivery_radius(api_client, make_restaurant):
    # Chennai coordinates
    near = make_restaurant(
        name="Near Restaurant", latitude=Decimal("13.0827"), longitude=Decimal("80.2707"),
        delivery_radius_km=Decimal("10.00"),
    )
    # Far away (Mumbai coordinates, ~1000km from Chennai) with a small radius
    make_restaurant(
        name="Far Restaurant", latitude=Decimal("19.0760"), longitude=Decimal("72.8777"),
        delivery_radius_km=Decimal("5.00"),
    )

    response = api_client.get(LIST_URL, {"lat": "13.0827", "lng": "80.2707"})

    names = {r["name"] for r in response.json()["data"]}
    assert names == {near.name}
    assert response.json()["data"][0]["distance_km"] is not None


def test_only_open_filter(api_client, make_restaurant):
    from apps.restaurants.models import DayOfWeek
    from django.utils import timezone

    open_restaurant = make_restaurant(name="Open Now")
    closed_restaurant = make_restaurant(name="Closed Now")
    today = timezone.localtime().weekday()
    closed_restaurant.business_hours.filter(day_of_week=today).update(is_closed=True)

    response = api_client.get(LIST_URL, {"only_open": "true"})

    names = {r["name"] for r in response.json()["data"]}
    assert open_restaurant.name in names
    assert closed_restaurant.name not in names

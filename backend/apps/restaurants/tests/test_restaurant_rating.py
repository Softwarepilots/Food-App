import pytest

pytestmark = pytest.mark.django_db


def _ratings_url(pk):
    return f"/api/v1/restaurants/{pk}/ratings/"


def test_rating_breakdown_empty(api_client, make_restaurant):
    restaurant = make_restaurant()

    response = api_client.get(_ratings_url(restaurant.id))

    assert response.status_code == 200
    body = response.json()["data"]
    assert body["total_reviews"] == 0
    assert body["breakdown"] == {"1": 0, "2": 0, "3": 0, "4": 0, "5": 0}


def test_rating_breakdown_reflects_reviews(api_client, make_restaurant, customer_user, other_owner_user):
    from apps.orders.models import Review

    restaurant = make_restaurant()
    Review.objects.create(user=customer_user, restaurant=restaurant, rating=5, comment="Great")
    Review.objects.create(user=other_owner_user, restaurant=restaurant, rating=3, comment="Okay")

    response = api_client.get(_ratings_url(restaurant.id))

    body = response.json()["data"]
    assert body["breakdown"]["5"] == 1
    assert body["breakdown"]["3"] == 1
    assert body["total_reviews"] == 2  # kept in sync by the orders.signals rating-recompute hook
    assert float(body["average_rating"]) == 4.0

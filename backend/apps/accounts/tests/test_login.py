import pytest

pytestmark = pytest.mark.django_db

LOGIN_URL = "/api/v1/auth/login/"
ME_URL = "/api/v1/auth/me/"


def test_login_success(api_client, make_user):
    make_user(email="login@test.com", password="S3cure!Pass123")

    response = api_client.post(LOGIN_URL, {"email": "login@test.com", "password": "S3cure!Pass123"}, format="json")

    assert response.status_code == 200
    body = response.json()["data"]
    assert body["user"]["email"] == "login@test.com"
    assert "access" in body and "refresh" in body


def test_login_wrong_password(api_client, make_user):
    make_user(email="login@test.com", password="S3cure!Pass123")

    response = api_client.post(LOGIN_URL, {"email": "login@test.com", "password": "wrong"}, format="json")

    assert response.status_code == 401


def test_login_nonexistent_user(api_client):
    response = api_client.post(LOGIN_URL, {"email": "nobody@test.com", "password": "whatever"}, format="json")

    assert response.status_code == 401


def test_login_soft_deleted_user_rejected(api_client, make_user):
    user = make_user(email="login@test.com", password="S3cure!Pass123")
    user.delete()  # soft delete: sets is_active=False

    response = api_client.post(LOGIN_URL, {"email": "login@test.com", "password": "S3cure!Pass123"}, format="json")

    assert response.status_code == 401


def test_me_requires_authentication(api_client):
    response = api_client.get(ME_URL)

    assert response.status_code == 401


def test_me_returns_current_user(api_client, make_user):
    make_user(email="login@test.com", password="S3cure!Pass123")
    login_response = api_client.post(
        LOGIN_URL, {"email": "login@test.com", "password": "S3cure!Pass123"}, format="json"
    )
    access = login_response.json()["data"]["access"]

    response = api_client.get(ME_URL, HTTP_AUTHORIZATION=f"Bearer {access}")

    assert response.status_code == 200
    assert response.json()["data"]["email"] == "login@test.com"

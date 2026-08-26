import pytest

pytestmark = pytest.mark.django_db

LOGIN_URL = "/api/v1/auth/login/"
LOGOUT_URL = "/api/v1/auth/logout/"
REFRESH_URL = "/api/v1/auth/token/refresh/"


def _login(api_client, make_user):
    make_user(email="logout@test.com", password="S3cure!Pass123")
    response = api_client.post(LOGIN_URL, {"email": "logout@test.com", "password": "S3cure!Pass123"}, format="json")
    return response.json()["data"]


def test_logout_requires_authentication(api_client, make_user):
    tokens = _login(api_client, make_user)

    response = api_client.post(LOGOUT_URL, {"refresh": tokens["refresh"]}, format="json")

    assert response.status_code == 401


def test_logout_blacklists_refresh_token(api_client, make_user):
    tokens = _login(api_client, make_user)

    response = api_client.post(
        LOGOUT_URL, {"refresh": tokens["refresh"]}, format="json", HTTP_AUTHORIZATION=f"Bearer {tokens['access']}"
    )
    assert response.status_code == 205

    reuse_response = api_client.post(REFRESH_URL, {"refresh": tokens["refresh"]}, format="json")
    assert reuse_response.status_code == 401


def test_refresh_rotates_and_blacklists_original_token(api_client, make_user):
    tokens = _login(api_client, make_user)

    first_refresh = api_client.post(REFRESH_URL, {"refresh": tokens["refresh"]}, format="json")
    assert first_refresh.status_code == 200
    assert "refresh" in first_refresh.json()

    reuse_response = api_client.post(REFRESH_URL, {"refresh": tokens["refresh"]}, format="json")
    assert reuse_response.status_code == 401

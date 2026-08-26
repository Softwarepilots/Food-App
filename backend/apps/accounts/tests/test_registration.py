import pytest

pytestmark = pytest.mark.django_db

REGISTER_URL = "/api/v1/auth/register/"


def _payload(**overrides):
    payload = {
        "email": "newuser@test.com",
        "phone_number": "+919876543220",
        "full_name": "New User",
        "role": "customer",
        "password": "S3cure!Pass123",
        "password_confirm": "S3cure!Pass123",
    }
    payload.update(overrides)
    return payload


def test_register_success(api_client, mailoutbox):
    response = api_client.post(REGISTER_URL, _payload(), format="json")

    assert response.status_code == 201
    body = response.json()["data"]
    assert body["user"]["email"] == "newuser@test.com"
    assert body["user"]["is_email_verified"] is False
    assert "access" in body and "refresh" in body
    assert len(mailoutbox) == 1
    assert "verify" in mailoutbox[0].subject.lower()


def test_register_password_mismatch(api_client):
    response = api_client.post(REGISTER_URL, _payload(password_confirm="different"), format="json")

    assert response.status_code == 400
    assert "password_confirm" in response.json()["error"]["details"]


def test_register_admin_role_rejected(api_client):
    response = api_client.post(REGISTER_URL, _payload(role="admin"), format="json")

    assert response.status_code == 400
    assert "role" in response.json()["error"]["details"]


def test_register_duplicate_email_rejected(api_client, make_user):
    make_user(email="newuser@test.com", phone_number="+919876543299")

    response = api_client.post(REGISTER_URL, _payload(), format="json")

    assert response.status_code == 400
    assert "email" in response.json()["error"]["details"]


def test_register_weak_password_rejected(api_client):
    response = api_client.post(
        REGISTER_URL, _payload(password="short", password_confirm="short"), format="json"
    )

    assert response.status_code == 400

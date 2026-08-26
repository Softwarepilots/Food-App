import pytest
from django.utils.encoding import force_bytes
from django.utils.http import urlsafe_base64_encode

from apps.accounts.tokens import email_verification_token_generator

pytestmark = pytest.mark.django_db

CONFIRM_URL = "/api/v1/auth/email/verify/confirm/"
RESEND_URL = "/api/v1/auth/email/verify/resend/"
LOGIN_URL = "/api/v1/auth/login/"


def _uid_and_token(user):
    return urlsafe_base64_encode(force_bytes(user.pk)), email_verification_token_generator.make_token(user)


def test_email_verify_confirm_success(api_client, make_user):
    user = make_user(email="verify@test.com")
    uid, token = _uid_and_token(user)

    response = api_client.post(CONFIRM_URL, {"uid": uid, "token": token}, format="json")

    assert response.status_code == 200
    user.refresh_from_db()
    assert user.is_email_verified is True


def test_email_verify_confirm_invalid_token(api_client, make_user):
    user = make_user(email="verify@test.com")
    uid, _ = _uid_and_token(user)

    response = api_client.post(CONFIRM_URL, {"uid": uid, "token": "garbage"}, format="json")

    assert response.status_code == 400


def test_email_verify_confirm_idempotent(api_client, make_user):
    user = make_user(email="verify@test.com")
    uid, token = _uid_and_token(user)

    first = api_client.post(CONFIRM_URL, {"uid": uid, "token": token}, format="json")
    second = api_client.post(CONFIRM_URL, {"uid": uid, "token": token}, format="json")

    assert first.status_code == 200
    assert second.status_code == 200


def test_email_verify_resend_requires_authentication(api_client):
    response = api_client.post(RESEND_URL, {}, format="json")

    assert response.status_code == 401


def test_email_verify_resend_sends_new_email(api_client, make_user, mailoutbox):
    make_user(email="verify@test.com", password="S3cure!Pass123")
    login = api_client.post(LOGIN_URL, {"email": "verify@test.com", "password": "S3cure!Pass123"}, format="json")
    access = login.json()["data"]["access"]

    response = api_client.post(RESEND_URL, {}, format="json", HTTP_AUTHORIZATION=f"Bearer {access}")

    assert response.status_code == 200
    assert len(mailoutbox) == 1


def test_email_verify_resend_noop_when_already_verified(api_client, make_user, mailoutbox):
    make_user(email="verify@test.com", password="S3cure!Pass123", is_email_verified=True)
    login = api_client.post(LOGIN_URL, {"email": "verify@test.com", "password": "S3cure!Pass123"}, format="json")
    access = login.json()["data"]["access"]

    response = api_client.post(RESEND_URL, {}, format="json", HTTP_AUTHORIZATION=f"Bearer {access}")

    assert response.status_code == 200
    assert len(mailoutbox) == 0

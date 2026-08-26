import pytest
from django.contrib.auth.tokens import default_token_generator
from django.utils.encoding import force_bytes
from django.utils.http import urlsafe_base64_encode

pytestmark = pytest.mark.django_db

FORGOT_URL = "/api/v1/auth/password/forgot/"
CONFIRM_URL = "/api/v1/auth/password/forgot/confirm/"
LOGIN_URL = "/api/v1/auth/login/"


def _uid_and_token(user):
    return urlsafe_base64_encode(force_bytes(user.pk)), default_token_generator.make_token(user)


def test_forgot_password_request_existing_user_sends_email(api_client, make_user, mailoutbox):
    make_user(email="reset@test.com")

    response = api_client.post(FORGOT_URL, {"email": "reset@test.com"}, format="json")

    assert response.status_code == 200
    assert len(mailoutbox) == 1
    assert "reset" in mailoutbox[0].subject.lower()


def test_forgot_password_request_unknown_email_no_enumeration(api_client, mailoutbox):
    response = api_client.post(FORGOT_URL, {"email": "unknown@test.com"}, format="json")

    assert response.status_code == 200
    assert len(mailoutbox) == 0


def test_forgot_password_confirm_success(api_client, make_user):
    user = make_user(email="reset@test.com", password="OldPass!123")
    uid, token = _uid_and_token(user)

    response = api_client.post(
        CONFIRM_URL,
        {"uid": uid, "token": token, "new_password": "NewPass!456", "new_password_confirm": "NewPass!456"},
        format="json",
    )
    assert response.status_code == 200

    login_response = api_client.post(LOGIN_URL, {"email": "reset@test.com", "password": "NewPass!456"}, format="json")
    assert login_response.status_code == 200


def test_forgot_password_confirm_invalid_token(api_client, make_user):
    user = make_user(email="reset@test.com")
    uid, _ = _uid_and_token(user)

    response = api_client.post(
        CONFIRM_URL,
        {"uid": uid, "token": "bad-token", "new_password": "NewPass!456", "new_password_confirm": "NewPass!456"},
        format="json",
    )

    assert response.status_code == 400


def test_forgot_password_confirm_password_mismatch(api_client, make_user):
    user = make_user(email="reset@test.com")
    uid, token = _uid_and_token(user)

    response = api_client.post(
        CONFIRM_URL,
        {"uid": uid, "token": token, "new_password": "NewPass!456", "new_password_confirm": "Different!789"},
        format="json",
    )

    assert response.status_code == 400

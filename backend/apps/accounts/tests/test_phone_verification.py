import pytest
from django.utils import timezone

from apps.accounts.models import OTPPurpose
from apps.accounts.services import OTPService

pytestmark = pytest.mark.django_db

REQUEST_URL = "/api/v1/auth/phone/verify/request/"
CONFIRM_URL = "/api/v1/auth/phone/verify/confirm/"
LOGIN_URL = "/api/v1/auth/login/"


def _login(api_client, make_user, **extra):
    make_user(email="phone@test.com", password="S3cure!Pass123", **extra)
    response = api_client.post(LOGIN_URL, {"email": "phone@test.com", "password": "S3cure!Pass123"}, format="json")
    return response.json()["data"]["access"]


def test_phone_verify_request_requires_authentication(api_client):
    response = api_client.post(REQUEST_URL, {}, format="json")

    assert response.status_code == 401


def test_phone_verify_request_returns_debug_otp_in_debug_mode(api_client, make_user, settings):
    settings.DEBUG = True
    access = _login(api_client, make_user)

    response = api_client.post(REQUEST_URL, {}, format="json", HTTP_AUTHORIZATION=f"Bearer {access}")

    assert response.status_code == 200
    assert "debug_otp" in response.json()["data"]


def test_phone_verify_confirm_success(api_client, make_user, settings):
    settings.DEBUG = True
    access = _login(api_client, make_user)
    request_response = api_client.post(REQUEST_URL, {}, format="json", HTTP_AUTHORIZATION=f"Bearer {access}")
    code = request_response.json()["data"]["debug_otp"]

    response = api_client.post(CONFIRM_URL, {"otp": code}, format="json", HTTP_AUTHORIZATION=f"Bearer {access}")

    assert response.status_code == 200
    from apps.accounts.models import User

    user = User.objects.get(email="phone@test.com")
    assert user.is_phone_verified is True


def test_phone_verify_confirm_wrong_code(api_client, make_user):
    access = _login(api_client, make_user)
    api_client.post(REQUEST_URL, {}, format="json", HTTP_AUTHORIZATION=f"Bearer {access}")

    response = api_client.post(CONFIRM_URL, {"otp": "000000"}, format="json", HTTP_AUTHORIZATION=f"Bearer {access}")

    assert response.status_code == 400


def test_phone_verify_confirm_no_otp_requested(api_client, make_user):
    access = _login(api_client, make_user)

    response = api_client.post(CONFIRM_URL, {"otp": "123456"}, format="json", HTTP_AUTHORIZATION=f"Bearer {access}")

    assert response.status_code == 400


def test_phone_verify_confirm_expired_otp(api_client, make_user):
    user = make_user(email="phone@test.com")
    otp, code = OTPService.generate(user, OTPPurpose.PHONE_VERIFICATION, user.phone_number)
    otp.expires_at = timezone.now() - timezone.timedelta(minutes=1)
    otp.save(update_fields=["expires_at"])

    with pytest.raises(Exception):
        OTPService.verify(user, OTPPurpose.PHONE_VERIFICATION, code)


def test_otp_locks_after_max_attempts(make_user, settings):
    settings.OTP_MAX_ATTEMPTS = 2
    user = make_user(email="phone@test.com")
    _, code = OTPService.generate(user, OTPPurpose.PHONE_VERIFICATION, user.phone_number)

    for _ in range(2):
        with pytest.raises(Exception):
            OTPService.verify(user, OTPPurpose.PHONE_VERIFICATION, "000000")

    with pytest.raises(Exception):
        OTPService.verify(user, OTPPurpose.PHONE_VERIFICATION, code)


def test_otp_resend_cooldown(make_user, settings):
    settings.OTP_RESEND_COOLDOWN_SECONDS = 3600
    user = make_user(email="phone@test.com")
    OTPService.generate(user, OTPPurpose.PHONE_VERIFICATION, user.phone_number)

    with pytest.raises(Exception):
        OTPService.generate(user, OTPPurpose.PHONE_VERIFICATION, user.phone_number)

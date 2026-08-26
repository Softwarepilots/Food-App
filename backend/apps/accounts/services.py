import logging
import secrets
from datetime import timedelta

from django.conf import settings
from django.contrib.auth.hashers import check_password, make_password
from django.contrib.auth.tokens import default_token_generator
from django.core.mail import send_mail
from django.utils import timezone
from django.utils.encoding import force_bytes
from django.utils.http import urlsafe_base64_encode

from apps.common.exceptions import ApplicationError

from .models import OTP, User
from .tokens import email_verification_token_generator

logger = logging.getLogger("apps")


def send_verification_email(user):
    token = email_verification_token_generator.make_token(user)
    uid = urlsafe_base64_encode(force_bytes(user.pk))
    link = f"{settings.FRONTEND_EMAIL_VERIFY_URL}?uid={uid}&token={token}"
    send_mail(
        subject="Verify your email address",
        message=(
            f"Hi {user.full_name},\n\n"
            f"Please verify your email address by opening this link:\n{link}\n\n"
            "If you did not create this account, you can ignore this email.\n"
        ),
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[user.email],
        fail_silently=False,
    )


def send_password_reset_email(user):
    token = default_token_generator.make_token(user)
    uid = urlsafe_base64_encode(force_bytes(user.pk))
    link = f"{settings.FRONTEND_PASSWORD_RESET_URL}?uid={uid}&token={token}"
    send_mail(
        subject="Reset your password",
        message=(
            f"Hi {user.full_name},\n\n"
            f"We received a request to reset your password. Open this link to choose a new one:\n{link}\n\n"
            "If you did not request this, you can safely ignore this email.\n"
        ),
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[user.email],
        fail_silently=False,
    )


def send_sms(phone_number, message):
    """SMS transport stub. No SMS gateway is wired into this project's tech stack
    yet (Twilio/MSG91/etc.) — this logs the message so the OTP flow around it is
    fully exercisable end-to-end. Swap this function's body for a real gateway
    client call when a provider is chosen; nothing else in the OTP flow needs to
    change."""
    logger.info("SMS to %s: %s", phone_number, message)


def get_or_create_user_by_phone(phone_number):
    """Fetches the account for `phone_number`, creating a bare (nameless,
    passwordless) one on first contact. Backs the phone+OTP login/register
    flow, where there's no separate registration step — the first OTP
    request for an unknown number silently provisions the account, and
    `full_name` gets filled in on OTP verification."""
    user = User.objects.filter(phone_number=phone_number).first()
    if user:
        return user, False

    user = User.objects.create_user(phone_number=phone_number, password=None)
    return user, True


class OTPService:
    @staticmethod
    def generate(user, purpose, destination):
        cooldown = settings.OTP_RESEND_COOLDOWN_SECONDS
        recent = OTP.objects.filter(user=user, purpose=purpose, is_used=False).order_by("-created_at").first()
        if recent and not recent.is_expired():
            seconds_since = (timezone.now() - recent.created_at).total_seconds()
            if seconds_since < cooldown:
                raise ApplicationError(
                    f"Please wait {int(cooldown - seconds_since)}s before requesting another OTP.",
                    code="otp_cooldown",
                    status_code=429,
                )

        OTP.objects.filter(user=user, purpose=purpose, is_used=False).update(is_used=True)

        code = "".join(secrets.choice("0123456789") for _ in range(settings.OTP_LENGTH))
        otp = OTP.objects.create(
            user=user,
            purpose=purpose,
            destination=destination,
            code_hash=make_password(code),
            expires_at=timezone.now() + timedelta(minutes=settings.OTP_EXPIRY_MINUTES),
        )
        logger.info("Generated OTP id=%s user=%s purpose=%s destination=%s", otp.id, user.id, purpose, destination)
        return otp, code

    @staticmethod
    def verify(user, purpose, code):
        otp = OTP.objects.filter(user=user, purpose=purpose, is_used=False).order_by("-created_at").first()
        if not otp:
            raise ApplicationError("No active OTP found. Please request a new one.", code="otp_not_found", status_code=400)
        if otp.is_expired():
            raise ApplicationError("This OTP has expired. Please request a new one.", code="otp_expired", status_code=400)
        if otp.attempts >= settings.OTP_MAX_ATTEMPTS:
            raise ApplicationError(
                "Maximum verification attempts exceeded. Please request a new one.",
                code="otp_locked",
                status_code=400,
            )

        otp.attempts += 1
        otp.save(update_fields=["attempts"])

        if not check_password(code, otp.code_hash):
            raise ApplicationError("Invalid OTP.", code="otp_invalid", status_code=400)

        otp.is_used = True
        otp.save(update_fields=["is_used"])
        return otp

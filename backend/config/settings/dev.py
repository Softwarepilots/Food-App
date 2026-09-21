"""Local development settings."""

from .base import *  # noqa: F401,F403

DEBUG = True

ALLOWED_HOSTS = ["*"]

# Local Flutter dev builds and emulators call the API from varying hosts/ports;
# keep this permissive locally and lock it down via CORS_ALLOWED_ORIGINS in staging/prod.
CORS_ALLOW_ALL_ORIGINS = True

REST_FRAMEWORK["DEFAULT_RENDERER_CLASSES"] = (
    "rest_framework.renderers.JSONRenderer",
    "rest_framework.renderers.BrowsableAPIRenderer",
)

LOGGING["loggers"]["django"]["level"] = "DEBUG"
LOGGING["loggers"]["apps"]["level"] = "DEBUG"

# No real SMTP credentials needed locally — verification/reset emails print to the console.
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# Production-tuned throttle rates (e.g. 5 OTPs/hour) make repeated manual
# QA passes against a single local tester account hit "throttled" constantly.
# Loosen them locally — this is a single-user dev box, not shared traffic.
REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"] = {
    "register": "100/hour",
    "login": "200/hour",
    "otp": "100/hour",
    "password_reset": "100/hour",
}

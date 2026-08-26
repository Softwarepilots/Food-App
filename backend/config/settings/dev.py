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

import logging

from django.core.exceptions import PermissionDenied as DjangoPermissionDenied
from django.http import Http404
from rest_framework import exceptions as drf_exceptions
from rest_framework.response import Response
from rest_framework.views import exception_handler as drf_default_exception_handler

logger = logging.getLogger("apps")


class ApplicationError(Exception):
    """Base class for domain/business-rule errors raised from the service layer.

    Services raise this (or a subclass) instead of returning error tuples, so
    views stay thin and error formatting stays centralized in this handler.
    """

    def __init__(self, message, code="application_error", status_code=400):
        self.message = message
        self.code = code
        self.status_code = status_code
        super().__init__(message)


def custom_exception_handler(exc, context):
    """Project-wide DRF exception handler producing one consistent error envelope:

    {"success": false, "error": {"code": str, "message": str, "details": ...}}
    """

    if isinstance(exc, ApplicationError):
        logger.warning("ApplicationError [%s]: %s", exc.code, exc.message)
        return Response(
            {
                "success": False,
                "error": {"code": exc.code, "message": exc.message, "details": None},
            },
            status=exc.status_code,
        )

    if isinstance(exc, DjangoPermissionDenied):
        exc = drf_exceptions.PermissionDenied(str(exc))

    if isinstance(exc, Http404):
        exc = drf_exceptions.NotFound()

    response = drf_default_exception_handler(exc, context)

    if response is None:
        logger.exception("Unhandled exception", exc_info=exc)
        return Response(
            {
                "success": False,
                "error": {
                    "code": "internal_server_error",
                    "message": "An unexpected error occurred. Please try again later.",
                    "details": None,
                },
            },
            status=500,
        )

    details = response.data if isinstance(response.data, (dict, list)) else {"detail": response.data}
    response.data = {
        "success": False,
        "error": {
            "code": getattr(exc, "default_code", "error"),
            "message": _extract_message(details),
            "details": details,
        },
    }
    return response


def _extract_message(details):
    if isinstance(details, dict) and "detail" in details:
        return str(details["detail"])
    if isinstance(details, list) and details:
        return str(details[0])
    return "Request could not be processed."

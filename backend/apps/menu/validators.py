from decimal import Decimal

from django.core.exceptions import ValidationError

ALLOWED_GST_RATES = (Decimal("0.00"), Decimal("5.00"), Decimal("12.00"), Decimal("18.00"), Decimal("28.00"))


def validate_gst_rate(value):
    if Decimal(value) not in ALLOWED_GST_RATES:
        allowed = ", ".join(f"{rate}%" for rate in ALLOWED_GST_RATES)
        raise ValidationError(f"GST rate must be one of the standard slabs: {allowed}.")

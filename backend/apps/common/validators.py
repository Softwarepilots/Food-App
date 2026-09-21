from decimal import Decimal

from django.core.validators import MaxValueValidator, MinValueValidator, RegexValidator

phone_number_validator = RegexValidator(
    regex=r"^\+?[1-9]\d{7,14}$",
    message="Enter a valid phone number in E.164 format, e.g. +919876543210.",
)

pincode_validator = RegexValidator(
    regex=r"^\d{4,10}$",
    message="Enter a valid postal/PIN code.",
)

coupon_code_validator = RegexValidator(
    regex=r"^[A-Z0-9_-]{3,30}$",
    message="Coupon code must be 3-30 characters: uppercase letters, digits, hyphens or underscores.",
)

vehicle_number_validator = RegexValidator(
    regex=r"^[A-Z0-9\- ]{4,20}$",
    message="Enter a valid vehicle registration number.",
)

license_number_validator = RegexValidator(
    regex=r"^[A-Z0-9\-]{4,30}$",
    message="Enter a valid driving license number.",
)

pan_number_validator = RegexValidator(
    regex=r"^[A-Z]{5}[0-9]{4}[A-Z]$",
    message="Enter a valid PAN (format: ABCDE1234F).",
)

fssai_number_validator = RegexValidator(
    regex=r"^\d{14}$",
    message="Enter a valid 14-digit FSSAI license number.",
)

gst_number_validator = RegexValidator(
    regex=r"^\d{2}[A-Z]{5}\d{4}[A-Z]\d[Z][A-Z\d]$",
    message="Enter a valid 15-character GSTIN.",
)

shop_license_number_validator = RegexValidator(
    regex=r"^[A-Z0-9\-/]{4,30}$",
    message="Enter a valid shop/trade license number.",
)

latitude_validators = [MinValueValidator(Decimal("-90")), MaxValueValidator(Decimal("90"))]
longitude_validators = [MinValueValidator(Decimal("-180")), MaxValueValidator(Decimal("180"))]
rating_validators = [MinValueValidator(Decimal("0")), MaxValueValidator(Decimal("5"))]
percentage_validators = [MinValueValidator(Decimal("0")), MaxValueValidator(Decimal("100"))]

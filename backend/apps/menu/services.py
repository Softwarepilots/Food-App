import logging
from decimal import ROUND_HALF_UP, Decimal

from django.utils import timezone

from apps.common.exceptions import ApplicationError
from apps.common.storage import SupabaseStorageService

from .models import FoodDiscountType, FoodImage

logger = logging.getLogger("apps")

ALLOWED_IMAGE_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}
TWO_PLACES = Decimal("0.01")


def _validate_image(file, max_size_bytes):
    if file.content_type not in ALLOWED_IMAGE_CONTENT_TYPES:
        raise ApplicationError(
            f"Unsupported file type '{file.content_type}'. Allowed: {', '.join(sorted(ALLOWED_IMAGE_CONTENT_TYPES))}.",
            code="unsupported_file_type",
        )
    if file.size > max_size_bytes:
        raise ApplicationError(
            f"File is too large. Maximum size is {max_size_bytes // (1024 * 1024)}MB.",
            code="file_too_large",
        )


def upload_food_image(food, file, caption="", is_primary=False, max_size_bytes=5 * 1024 * 1024):
    _validate_image(file, max_size_bytes)
    image_url = SupabaseStorageService().upload(file, folder=f"foods/{food.id}/images")
    return FoodImage.objects.create(food=food, image_url=image_url, caption=caption, is_primary=is_primary)


def delete_food_image(image):
    SupabaseStorageService().delete(image.image_url)
    image.delete(hard=True)


def get_active_discount(food):
    now = timezone.now()
    return (
        food.discounts.filter(is_active=True, valid_from__lte=now, valid_until__gte=now)
        .order_by("-created_at")
        .first()
    )


def calculate_price(food, variant=None):
    """Full price breakdown for one unit of `food` (or a specific `variant`),
    applying the food's active discount (if any) before GST."""
    unit_price = variant.price if variant is not None else food.base_price
    discount = get_active_discount(food)

    discount_amount = Decimal("0.00")
    if discount:
        if discount.discount_type == FoodDiscountType.PERCENTAGE:
            discount_amount = (unit_price * discount.value / Decimal("100")).quantize(TWO_PLACES, rounding=ROUND_HALF_UP)
            if discount.max_discount_amount is not None:
                discount_amount = min(discount_amount, discount.max_discount_amount)
        else:
            discount_amount = min(discount.value, unit_price)

    price_after_discount = unit_price - discount_amount
    gst_amount = (price_after_discount * food.gst_rate / Decimal("100")).quantize(TWO_PLACES, rounding=ROUND_HALF_UP)
    final_price = price_after_discount + gst_amount

    return {
        "unit_price": unit_price,
        "discount_amount": discount_amount,
        "price_after_discount": price_after_discount,
        "gst_rate": food.gst_rate,
        "gst_amount": gst_amount,
        "final_price": final_price,
    }


def adjust_stock(instance, delta):
    """Adjust `stock_quantity` on a Food or FoodVariant by `delta` (negative to
    decrement). No-op if the instance doesn't track inventory. Auto-hides the
    item (`is_available=False`) once stock reaches zero, and returns a status
    string ('ok' | 'out_of_stock' | 'low_stock' | 'not_tracked') so callers can
    decide whether to notify anyone."""
    if not instance.track_inventory:
        return "not_tracked"

    instance.stock_quantity = max(instance.stock_quantity + delta, 0)
    update_fields = ["stock_quantity"]

    if instance.stock_quantity == 0 and instance.is_available:
        instance.is_available = False
        update_fields.append("is_available")
        status = "out_of_stock"
    elif instance.is_low_stock:
        status = "low_stock"
    else:
        status = "ok"

    instance.save(update_fields=update_fields)
    return status

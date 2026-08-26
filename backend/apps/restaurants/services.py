from django.db import transaction
from django.utils import timezone

from apps.common.exceptions import ApplicationError
from apps.common.geo import haversine_distance_km
from apps.common.storage import SupabaseStorageService

from .models import (
    RestaurantApprovalStatus,
    RestaurantBusinessHours,
    RestaurantDocument,
    RestaurantDocumentStatus,
    RestaurantImage,
)

ALLOWED_IMAGE_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_DOCUMENT_CONTENT_TYPES = {"image/jpeg", "image/png", "application/pdf"}


def _validate_upload(file, allowed_content_types, max_size_bytes):
    if file.content_type not in allowed_content_types:
        raise ApplicationError(
            f"Unsupported file type '{file.content_type}'. Allowed: {', '.join(sorted(allowed_content_types))}.",
            code="unsupported_file_type",
        )
    if file.size > max_size_bytes:
        raise ApplicationError(
            f"File is too large. Maximum size is {max_size_bytes // (1024 * 1024)}MB.",
            code="file_too_large",
        )


def approve_restaurant(restaurant, admin_user):
    restaurant.approval_status = RestaurantApprovalStatus.APPROVED
    restaurant.rejection_reason = ""
    restaurant.approved_at = timezone.now()
    restaurant.approved_by = admin_user
    restaurant.save(update_fields=["approval_status", "rejection_reason", "approved_at", "approved_by"])
    return restaurant


def reject_restaurant(restaurant, admin_user, reason):
    restaurant.approval_status = RestaurantApprovalStatus.REJECTED
    restaurant.rejection_reason = reason
    restaurant.approved_at = None
    restaurant.approved_by = admin_user
    restaurant.save(update_fields=["approval_status", "rejection_reason", "approved_at", "approved_by"])
    return restaurant


@transaction.atomic
def replace_business_hours(restaurant, entries):
    """Bulk-replace a restaurant's weekly schedule. `entries` is a list of dicts
    with day_of_week/opening_time/closing_time/is_closed, one per day supplied."""
    restaurant.business_hours.all().delete()
    created = [
        RestaurantBusinessHours(
            restaurant=restaurant,
            day_of_week=entry["day_of_week"],
            opening_time=entry.get("opening_time"),
            closing_time=entry.get("closing_time"),
            is_closed=entry.get("is_closed", False),
        )
        for entry in entries
    ]
    for hours in created:
        hours.full_clean()
        hours.save()
    return restaurant.business_hours.all()


def upload_restaurant_image(restaurant, file, caption="", is_primary=False, max_size_bytes=5 * 1024 * 1024):
    _validate_upload(file, ALLOWED_IMAGE_CONTENT_TYPES, max_size_bytes)
    image_url = SupabaseStorageService().upload(file, folder=f"restaurants/{restaurant.id}/images")
    return RestaurantImage.objects.create(
        restaurant=restaurant, image_url=image_url, caption=caption, is_primary=is_primary
    )


def delete_restaurant_image(image):
    SupabaseStorageService().delete(image.image_url)
    image.delete(hard=True)


def upload_restaurant_document(restaurant, file, document_type, max_size_bytes=5 * 1024 * 1024):
    _validate_upload(file, ALLOWED_DOCUMENT_CONTENT_TYPES, max_size_bytes)
    file_url = SupabaseStorageService().upload(file, folder=f"restaurants/{restaurant.id}/documents")
    return RestaurantDocument.objects.create(restaurant=restaurant, document_type=document_type, file_url=file_url)


def review_restaurant_document(document, admin_user, status, reason=""):
    document.status = status
    document.rejection_reason = reason if status == RestaurantDocumentStatus.REJECTED else ""
    document.reviewed_by = admin_user
    document.reviewed_at = timezone.now()
    document.save(update_fields=["status", "rejection_reason", "reviewed_by", "reviewed_at"])
    return document


def get_rating_breakdown(restaurant):
    from django.db.models import Count

    from apps.orders.models import Review

    breakdown = {str(star): 0 for star in range(1, 6)}
    counts = Review.objects.filter(restaurant=restaurant).values("rating").annotate(count=Count("id"))
    for row in counts:
        breakdown[str(row["rating"])] = row["count"]

    return {
        "average_rating": restaurant.average_rating,
        "total_reviews": restaurant.total_reviews,
        "breakdown": breakdown,
    }


def search_restaurants(queryset, *, city=None, category_slug=None, cuisine=None, search=None, lat=None, lng=None, only_open=None):
    """Applies DB-safe filters (city/category/name) via the queryset, then
    cuisine/distance/open-now in Python — kept out of SQL since ArrayField
    containment and haversine distance aren't portable across backends and
    the restaurant list is small enough for this to be cheap."""
    if city:
        queryset = queryset.filter(city__iexact=city)
    if category_slug:
        queryset = queryset.filter(categories__slug=category_slug)
    if search:
        queryset = queryset.filter(name__icontains=search)

    restaurants = list(queryset.distinct())

    if cuisine:
        cuisine_lower = cuisine.lower()
        restaurants = [r for r in restaurants if cuisine_lower in (tag.lower() for tag in r.cuisine_tags)]

    if lat is not None and lng is not None:
        lat, lng = float(lat), float(lng)
        in_range = []
        for restaurant in restaurants:
            distance = haversine_distance_km(lat, lng, restaurant.latitude, restaurant.longitude)
            if distance <= float(restaurant.delivery_radius_km):
                restaurant.distance_km = round(distance, 2)
                in_range.append(restaurant)
        in_range.sort(key=lambda r: r.distance_km)
        restaurants = in_range

    if only_open:
        restaurants = [r for r in restaurants if r.is_open_now]

    return restaurants

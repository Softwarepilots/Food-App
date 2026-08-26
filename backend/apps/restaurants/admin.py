from django.contrib import admin, messages

from . import services
from .models import (
    Favorite,
    Offer,
    Restaurant,
    RestaurantBusinessHours,
    RestaurantCategory,
    RestaurantDocument,
    RestaurantDocumentStatus,
    RestaurantImage,
)


class RestaurantImageInline(admin.TabularInline):
    model = RestaurantImage
    extra = 0
    fields = ("image_url", "caption", "is_primary", "sort_order")


class RestaurantBusinessHoursInline(admin.TabularInline):
    model = RestaurantBusinessHours
    extra = 0
    fields = ("day_of_week", "opening_time", "closing_time", "is_closed")


class RestaurantDocumentInline(admin.TabularInline):
    model = RestaurantDocument
    extra = 0
    fields = ("document_type", "file_url", "status", "rejection_reason")
    readonly_fields = ("file_url",)


@admin.register(Restaurant)
class RestaurantAdmin(admin.ModelAdmin):
    list_display = (
        "name", "owner", "city", "approval_status", "is_active", "is_accepting_orders",
        "average_rating", "total_reviews",
    )
    list_filter = ("approval_status", "is_active", "is_accepting_orders", "city")
    search_fields = ("name", "owner__email", "owner__full_name", "city")
    readonly_fields = (
        "id", "slug", "average_rating", "total_reviews", "approved_at", "approved_by", "created_at", "updated_at",
    )
    autocomplete_fields = ("owner", "categories")
    inlines = [RestaurantImageInline, RestaurantBusinessHoursInline, RestaurantDocumentInline]
    actions = ["approve_restaurants", "reject_restaurants"]

    def get_queryset(self, request):
        return Restaurant.all_objects.all()

    @admin.action(description="Approve selected restaurants")
    def approve_restaurants(self, request, queryset):
        count = 0
        for restaurant in queryset:
            services.approve_restaurant(restaurant, request.user)
            count += 1
        self.message_user(request, f"Approved {count} restaurant(s).", messages.SUCCESS)

    @admin.action(description="Reject selected restaurants")
    def reject_restaurants(self, request, queryset):
        count = 0
        for restaurant in queryset:
            services.reject_restaurant(restaurant, request.user, "Rejected via admin bulk action.")
            count += 1
        self.message_user(request, f"Rejected {count} restaurant(s).", messages.WARNING)


@admin.register(RestaurantCategory)
class RestaurantCategoryAdmin(admin.ModelAdmin):
    list_display = ("name", "slug", "is_active", "sort_order")
    list_filter = ("is_active",)
    search_fields = ("name",)
    readonly_fields = ("id", "slug")


@admin.register(RestaurantDocument)
class RestaurantDocumentAdmin(admin.ModelAdmin):
    list_display = ("restaurant", "document_type", "status", "reviewed_by", "reviewed_at", "created_at")
    list_filter = ("document_type", "status")
    search_fields = ("restaurant__name",)
    autocomplete_fields = ("restaurant", "reviewed_by")
    readonly_fields = ("id", "file_url", "created_at", "updated_at")
    actions = ["verify_documents", "reject_documents"]

    @admin.action(description="Verify selected documents")
    def verify_documents(self, request, queryset):
        count = 0
        for document in queryset:
            services.review_restaurant_document(document, request.user, RestaurantDocumentStatus.VERIFIED)
            count += 1
        self.message_user(request, f"Verified {count} document(s).", messages.SUCCESS)

    @admin.action(description="Reject selected documents")
    def reject_documents(self, request, queryset):
        count = 0
        for document in queryset:
            services.review_restaurant_document(
                document, request.user, RestaurantDocumentStatus.REJECTED, "Rejected via admin bulk action."
            )
            count += 1
        self.message_user(request, f"Rejected {count} document(s).", messages.WARNING)


@admin.register(Favorite)
class FavoriteAdmin(admin.ModelAdmin):
    list_display = ("user", "restaurant", "created_at")
    search_fields = ("user__email", "restaurant__name")
    autocomplete_fields = ("user", "restaurant")


@admin.register(Offer)
class OfferAdmin(admin.ModelAdmin):
    list_display = ("title", "restaurant", "offer_type", "is_active", "valid_from", "valid_until")
    list_filter = ("offer_type", "is_active")
    search_fields = ("title", "restaurant__name")
    autocomplete_fields = ("restaurant",)

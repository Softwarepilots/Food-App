from django.contrib import admin

from .models import Food, FoodAddon, FoodCategory, FoodDiscount, FoodImage, FoodReview, FoodVariant


class FoodVariantInline(admin.TabularInline):
    model = FoodVariant
    extra = 0
    fields = ("name", "price", "is_default", "is_available", "track_inventory", "stock_quantity")


class FoodAddonInline(admin.TabularInline):
    model = FoodAddon
    extra = 0
    fields = ("name", "price", "is_available", "max_quantity")


class FoodImageInline(admin.TabularInline):
    model = FoodImage
    extra = 0
    fields = ("image_url", "caption", "is_primary", "sort_order")


class FoodDiscountInline(admin.TabularInline):
    model = FoodDiscount
    extra = 0
    fields = ("discount_type", "value", "max_discount_amount", "valid_from", "valid_until", "is_active")


@admin.register(FoodCategory)
class FoodCategoryAdmin(admin.ModelAdmin):
    list_display = ("name", "restaurant", "sort_order")
    list_filter = ("restaurant",)
    search_fields = ("name", "restaurant__name")
    autocomplete_fields = ("restaurant",)


@admin.register(Food)
class FoodAdmin(admin.ModelAdmin):
    list_display = (
        "name", "restaurant", "category", "base_price", "gst_rate", "food_type",
        "is_available", "is_bestseller", "track_inventory", "stock_quantity",
    )
    list_filter = ("food_type", "is_available", "is_bestseller", "track_inventory")
    search_fields = ("name", "restaurant__name", "category__name")
    autocomplete_fields = ("restaurant", "category")
    inlines = [FoodVariantInline, FoodAddonInline, FoodImageInline, FoodDiscountInline]

    def get_queryset(self, request):
        return Food.all_objects.all()


@admin.register(FoodVariant)
class FoodVariantAdmin(admin.ModelAdmin):
    list_display = ("food", "name", "price", "is_default", "is_available", "track_inventory", "stock_quantity")
    list_filter = ("is_available", "track_inventory")
    search_fields = ("food__name", "name")
    autocomplete_fields = ("food",)


@admin.register(FoodAddon)
class FoodAddonAdmin(admin.ModelAdmin):
    list_display = ("food", "name", "price", "is_available", "max_quantity")
    search_fields = ("food__name", "name")
    autocomplete_fields = ("food",)


@admin.register(FoodImage)
class FoodImageAdmin(admin.ModelAdmin):
    list_display = ("food", "is_primary", "sort_order", "created_at")
    search_fields = ("food__name",)
    autocomplete_fields = ("food",)
    readonly_fields = ("id", "image_url", "created_at", "updated_at")


@admin.register(FoodDiscount)
class FoodDiscountAdmin(admin.ModelAdmin):
    list_display = ("food", "discount_type", "value", "is_active", "valid_from", "valid_until")
    list_filter = ("discount_type", "is_active")
    search_fields = ("food__name",)
    autocomplete_fields = ("food",)


@admin.register(FoodReview)
class FoodReviewAdmin(admin.ModelAdmin):
    list_display = ("food", "user", "rating", "created_at")
    list_filter = ("rating",)
    search_fields = ("food__name", "user__email", "user__full_name", "comment")
    autocomplete_fields = ("food", "user")
    readonly_fields = ("id", "created_at", "updated_at")

from django.contrib import admin

from .models import Coupon, Order, OrderItem, Review


class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    fields = ("food_name_snapshot", "variant_name_snapshot", "unit_price_snapshot", "quantity", "line_total")
    readonly_fields = fields
    can_delete = False


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ("order_number", "user", "restaurant", "status", "payment_status", "total_amount", "created_at")
    list_filter = ("status", "payment_status")
    search_fields = ("order_number", "user__email", "restaurant__name")
    autocomplete_fields = ("user", "restaurant", "delivery_partner", "coupon")
    readonly_fields = ("id", "order_number", "created_at", "updated_at")
    inlines = [OrderItemInline]

    def get_queryset(self, request):
        return Order.all_objects.all()


@admin.register(Coupon)
class CouponAdmin(admin.ModelAdmin):
    list_display = ("code", "discount_type", "discount_value", "is_active", "times_used", "valid_from", "valid_until")
    list_filter = ("discount_type", "is_active")
    search_fields = ("code", "description")


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ("restaurant", "user", "rating", "created_at")
    list_filter = ("rating",)
    search_fields = ("restaurant__name", "user__email", "comment")
    autocomplete_fields = ("user", "restaurant", "order")
    readonly_fields = ("id", "created_at", "updated_at")

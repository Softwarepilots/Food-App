from django.contrib import admin, messages

from .models import DeliveryPartner, DeliveryShift, ShiftBooking


@admin.register(DeliveryPartner)
class DeliveryPartnerAdmin(admin.ModelAdmin):
    list_display = ("user", "vehicle_type", "status", "is_verified", "rating_avg", "total_deliveries")
    list_filter = ("vehicle_type", "status", "is_verified")
    search_fields = ("user__email", "user__full_name", "vehicle_number", "license_number")
    autocomplete_fields = ("user",)
    readonly_fields = ("id", "rating_avg", "total_deliveries", "created_at", "updated_at")
    actions = ["verify_partners", "unverify_partners"]

    @admin.action(description="Verify selected delivery partners")
    def verify_partners(self, request, queryset):
        count = queryset.update(is_verified=True)
        self.message_user(request, f"Verified {count} delivery partner(s).", messages.SUCCESS)

    @admin.action(description="Un-verify selected delivery partners")
    def unverify_partners(self, request, queryset):
        count = queryset.update(is_verified=False)
        self.message_user(request, f"Un-verified {count} delivery partner(s).", messages.WARNING)


@admin.register(DeliveryShift)
class DeliveryShiftAdmin(admin.ModelAdmin):
    list_display = ("date", "start_time", "end_time", "rate_min_per_hour", "rate_max_per_hour", "capacity", "is_peak")
    list_filter = ("date", "is_peak")
    ordering = ("date", "start_time")


@admin.register(ShiftBooking)
class ShiftBookingAdmin(admin.ModelAdmin):
    list_display = ("shift", "delivery_partner", "status", "created_at")
    list_filter = ("status",)
    autocomplete_fields = ("delivery_partner",)

from django.contrib import admin, messages

from .models import DeliveryPartner


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

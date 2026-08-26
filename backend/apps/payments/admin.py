from django.contrib import admin

from .models import Payment, Wallet


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ("order", "method", "status", "amount", "refunded_amount", "created_at")
    list_filter = ("method", "status")
    search_fields = ("order__order_number", "razorpay_order_id", "razorpay_payment_id")
    autocomplete_fields = ("order",)
    readonly_fields = ("id", "created_at", "updated_at")


@admin.register(Wallet)
class WalletAdmin(admin.ModelAdmin):
    list_display = ("user", "balance", "currency", "is_active")
    search_fields = ("user__email", "user__full_name")
    autocomplete_fields = ("user",)
    readonly_fields = ("id", "balance", "created_at", "updated_at")

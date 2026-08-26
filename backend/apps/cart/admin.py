from django.contrib import admin

from .models import Cart, CartItem


class CartItemInline(admin.TabularInline):
    model = CartItem
    extra = 0
    fields = ("food", "variant", "quantity", "notes")
    autocomplete_fields = ("food", "variant")


@admin.register(Cart)
class CartAdmin(admin.ModelAdmin):
    list_display = ("user", "restaurant", "created_at", "updated_at")
    search_fields = ("user__email", "user__full_name", "restaurant__name")
    autocomplete_fields = ("user", "restaurant")
    inlines = [CartItemInline]


@admin.register(CartItem)
class CartItemAdmin(admin.ModelAdmin):
    list_display = ("cart", "food", "variant", "quantity")
    search_fields = ("cart__user__email", "food__name")
    autocomplete_fields = ("cart", "food", "variant")

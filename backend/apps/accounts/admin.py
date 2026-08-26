from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.forms import UserChangeForm as BaseUserChangeForm
from django.contrib.auth.forms import UserCreationForm as BaseUserCreationForm

from .models import OTP, Address, User


class UserCreationForm(BaseUserCreationForm):
    class Meta(BaseUserCreationForm.Meta):
        model = User
        fields = ("email", "phone_number", "full_name", "role")


class UserChangeForm(BaseUserChangeForm):
    class Meta(BaseUserChangeForm.Meta):
        model = User
        fields = "__all__"


class AddressInline(admin.TabularInline):
    model = Address
    extra = 0
    fields = ("label", "address_line1", "city", "state", "pincode", "is_default", "is_deleted")


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    add_form = UserCreationForm
    form = UserChangeForm
    model = User
    ordering = ("-created_at",)
    list_display = (
        "email", "full_name", "phone_number", "role", "is_active",
        "is_email_verified", "is_phone_verified", "is_staff", "created_at",
    )
    list_filter = ("role", "is_active", "is_email_verified", "is_phone_verified", "is_staff")
    search_fields = ("email", "full_name", "phone_number")
    readonly_fields = ("id", "created_at", "updated_at", "last_login")
    filter_horizontal = ("groups", "user_permissions")
    inlines = [AddressInline]
    fieldsets = (
        (None, {"fields": ("email", "password")}),
        ("Personal info", {"fields": ("full_name", "phone_number", "profile_image_url")}),
        (
            "Role & status",
            {
                "fields": (
                    "role", "is_active", "is_email_verified", "is_phone_verified",
                    "is_staff", "is_superuser", "groups", "user_permissions",
                )
            },
        ),
        ("Important dates", {"fields": ("last_login", "created_at", "updated_at")}),
    )
    add_fieldsets = (
        (None, {"fields": ("email", "phone_number", "full_name", "role", "password1", "password2")}),
    )

    def get_queryset(self, request):
        return User.all_objects.all()


@admin.register(Address)
class AddressAdmin(admin.ModelAdmin):
    list_display = ("user", "label", "city", "pincode", "is_default", "is_deleted", "created_at")
    list_filter = ("label", "is_default", "is_deleted")
    search_fields = ("user__email", "user__full_name", "address_line1", "city", "pincode")
    autocomplete_fields = ("user",)

    def get_queryset(self, request):
        return Address.all_objects.all()


@admin.register(OTP)
class OTPAdmin(admin.ModelAdmin):
    list_display = ("user", "purpose", "destination", "is_used", "attempts", "expires_at", "created_at")
    list_filter = ("purpose", "is_used")
    search_fields = ("user__email", "user__full_name", "destination")
    autocomplete_fields = ("user",)
    readonly_fields = ("id", "code_hash", "created_at", "updated_at")

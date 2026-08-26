from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.contrib.auth.models import PermissionsMixin
from django.db import models
from django.utils import timezone

from apps.common.models import BaseModel, SoftDeleteQuerySet, TimeStampedModel, UUIDPrimaryKeyModel
from apps.common.validators import (
    latitude_validators,
    longitude_validators,
    phone_number_validator,
    pincode_validator,
)


class UserRole(models.TextChoices):
    CUSTOMER = "customer", "Customer"
    RESTAURANT_OWNER = "restaurant_owner", "Restaurant Owner"
    DELIVERY_PARTNER = "delivery_partner", "Delivery Partner"
    ADMIN = "admin", "Admin"


class UserManager(BaseUserManager):
    """Default manager backing `User.objects`. Excludes soft-deleted accounts
    from every lookup, including authentication — a deactivated/deleted user
    cannot log in."""

    def get_queryset(self):
        return SoftDeleteQuerySet(self.model, using=self._db).alive()

    def _create_user(self, phone_number, password, **extra_fields):
        if not phone_number:
            raise ValueError("Users must have a phone number.")
        email = extra_fields.get("email")
        if email:
            extra_fields["email"] = self.normalize_email(email)
        user = self.model(phone_number=phone_number, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, phone_number, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)
        extra_fields.setdefault("role", UserRole.CUSTOMER)
        return self._create_user(phone_number, password, **extra_fields)

    def create_superuser(self, phone_number, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_email_verified", True)
        extra_fields.setdefault("is_phone_verified", True)
        extra_fields.setdefault("role", UserRole.ADMIN)
        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")
        return self._create_user(phone_number, password, **extra_fields)


class AllUsersManager(BaseUserManager):
    """Includes soft-deleted accounts — for admin/audit use only."""

    def get_queryset(self):
        return SoftDeleteQuerySet(self.model, using=self._db)


class User(UUIDPrimaryKeyModel, TimeStampedModel, AbstractBaseUser, PermissionsMixin):
    is_deleted = models.BooleanField(default=False, db_index=True)
    deleted_at = models.DateTimeField(null=True, blank=True)

    email = models.EmailField(unique=True, null=True, blank=True)
    phone_number = models.CharField(max_length=15, unique=True, validators=[phone_number_validator])
    full_name = models.CharField(max_length=150, blank=True)
    role = models.CharField(max_length=20, choices=UserRole.choices, default=UserRole.CUSTOMER, db_index=True)
    profile_image_url = models.URLField(blank=True)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    is_email_verified = models.BooleanField(default=False)
    is_phone_verified = models.BooleanField(default=False)

    objects = UserManager()
    all_objects = AllUsersManager()

    USERNAME_FIELD = "phone_number"
    REQUIRED_FIELDS = ["full_name"]

    class Meta:
        db_table = "accounts_user"
        verbose_name = "User"
        verbose_name_plural = "Users"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["role", "is_active"]),
        ]

    def __str__(self):
        return f"{self.full_name or 'Unnamed'} ({self.phone_number})"

    def get_full_name(self):
        return self.full_name

    def get_short_name(self):
        return self.full_name.split(" ")[0] if self.full_name else self.phone_number

    def delete(self, using=None, keep_parents=False, hard=False):
        if hard:
            return super().delete(using=using, keep_parents=keep_parents)
        self.is_deleted = True
        self.deleted_at = timezone.now()
        self.is_active = False
        self.save(using=using, update_fields=["is_deleted", "deleted_at", "is_active"])
        return None

    def restore(self):
        self.is_deleted = False
        self.deleted_at = None
        self.is_active = True
        self.save(update_fields=["is_deleted", "deleted_at", "is_active"])

    @property
    def is_customer(self):
        return self.role == UserRole.CUSTOMER

    @property
    def is_restaurant_owner(self):
        return self.role == UserRole.RESTAURANT_OWNER

    @property
    def is_delivery_partner(self):
        return self.role == UserRole.DELIVERY_PARTNER


class AddressLabel(models.TextChoices):
    HOME = "home", "Home"
    WORK = "work", "Work"
    OTHER = "other", "Other"


class Address(BaseModel):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="addresses")
    label = models.CharField(max_length=10, choices=AddressLabel.choices, default=AddressLabel.HOME)
    address_line1 = models.CharField(max_length=255)
    address_line2 = models.CharField(max_length=255, blank=True)
    city = models.CharField(max_length=100)
    state = models.CharField(max_length=100)
    pincode = models.CharField(max_length=10, validators=[pincode_validator])
    latitude = models.DecimalField(max_digits=9, decimal_places=6, validators=latitude_validators)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, validators=longitude_validators)
    is_default = models.BooleanField(default=False)

    class Meta:
        db_table = "accounts_address"
        verbose_name = "Address"
        verbose_name_plural = "Addresses"
        ordering = ["-is_default", "-created_at"]
        indexes = [
            models.Index(fields=["user", "is_default"]),
        ]

    def __str__(self):
        return f"{self.get_label_display()} - {self.address_line1}, {self.city}"


class OTPPurpose(models.TextChoices):
    PHONE_VERIFICATION = "phone_verification", "Phone Verification"
    PASSWORD_RESET = "password_reset", "Password Reset"
    LOGIN = "login", "Login"


class OTP(BaseModel):
    """Generic, reusable OTP record. Only phone verification consumes this today,
    but `purpose` makes it ready for OTP-based login/reset flows later without a
    schema change."""

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="otps")
    purpose = models.CharField(max_length=20, choices=OTPPurpose.choices)
    destination = models.CharField(max_length=150)
    code_hash = models.CharField(max_length=128)
    expires_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)
    is_used = models.BooleanField(default=False)

    class Meta:
        db_table = "accounts_otp"
        verbose_name = "OTP"
        verbose_name_plural = "OTPs"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "purpose", "is_used"]),
        ]

    def __str__(self):
        return f"OTP({self.purpose}) for {self.user.full_name}"

    def is_expired(self):
        return timezone.now() >= self.expires_at

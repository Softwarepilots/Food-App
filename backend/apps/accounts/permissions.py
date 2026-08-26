from rest_framework.permissions import BasePermission

from .models import UserRole


class HasRole(BasePermission):
    """Base class for role-gated permissions. Subclass and set `allowed_roles`."""

    allowed_roles = ()
    message = "You do not have the required role to perform this action."

    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated and user.role in self.allowed_roles)


class IsCustomer(HasRole):
    allowed_roles = (UserRole.CUSTOMER,)


class IsRestaurantOwner(HasRole):
    allowed_roles = (UserRole.RESTAURANT_OWNER,)


class IsDeliveryPartner(HasRole):
    allowed_roles = (UserRole.DELIVERY_PARTNER,)


class IsAdminRole(HasRole):
    allowed_roles = (UserRole.ADMIN,)


class IsEmailVerified(BasePermission):
    message = "Email verification is required for this action."

    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated and user.is_email_verified)


class IsPhoneVerified(BasePermission):
    message = "Phone verification is required for this action."

    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated and user.is_phone_verified)

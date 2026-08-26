from rest_framework.permissions import SAFE_METHODS, BasePermission

from apps.accounts.models import UserRole

from .models import Restaurant


def _resolve_restaurant(obj):
    """Objects passed to has_object_permission are either a Restaurant itself
    or something with a `.restaurant` FK (image/hours/document)."""
    return obj if isinstance(obj, Restaurant) else obj.restaurant


class IsRestaurantOwnerOfObject(BasePermission):
    """Object-level check: the request user must own the restaurant the object
    belongs to. Combine with role-level permissions for the list/create views."""

    message = "You do not own this restaurant."

    def has_object_permission(self, request, view, obj):
        user = request.user
        if not (user and user.is_authenticated):
            return False
        restaurant = _resolve_restaurant(obj)
        return restaurant.owner_id == user.id


class IsRestaurantOwnerOrAdmin(BasePermission):
    """Object-level check: owner of the restaurant, or an admin."""

    message = "You do not have permission to act on this restaurant."

    def has_object_permission(self, request, view, obj):
        user = request.user
        if not (user and user.is_authenticated):
            return False
        if user.role == UserRole.ADMIN:
            return True
        restaurant = _resolve_restaurant(obj)
        return restaurant.owner_id == user.id


class ReadOnlyOrIsRestaurantOwner(BasePermission):
    """Public read access; only the owning restaurant partner may write."""

    def has_permission(self, request, view):
        if request.method in SAFE_METHODS:
            return True
        user = request.user
        return bool(user and user.is_authenticated and user.role == UserRole.RESTAURANT_OWNER)

    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True
        user = request.user
        if not (user and user.is_authenticated):
            return False
        restaurant = _resolve_restaurant(obj)
        return restaurant.owner_id == user.id

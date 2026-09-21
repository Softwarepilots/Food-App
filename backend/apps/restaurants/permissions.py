from rest_framework.permissions import SAFE_METHODS, BasePermission

from apps.accounts.models import UserRole

from .models import Restaurant, RestaurantStaff, RestaurantStaffRole


def _resolve_restaurant(obj):
    """Objects passed to has_object_permission are either a Restaurant itself
    or something with a `.restaurant` FK (image/hours/document)."""
    return obj if isinstance(obj, Restaurant) else obj.restaurant


# Ordered weakest-to-strongest so `ROLE_RANK[role] >= ROLE_RANK[required]`
# answers "is this role at least as senior as required".
ROLE_RANK = {RestaurantStaffRole.STAFF: 1, RestaurantStaffRole.MANAGER: 2, "owner": 3}


def get_partner_role(user, restaurant):
    """Resolves a user's effective role on a specific restaurant: 'owner',
    'manager', 'staff', or None if they have no access to it at all. The
    owner is never a `RestaurantStaff` row — `Restaurant.owner` already
    identifies them."""
    if not (user and user.is_authenticated):
        return None
    if restaurant.owner_id == user.id:
        return "owner"
    membership = RestaurantStaff.objects.filter(restaurant=restaurant, user=user, is_active=True).first()
    return membership.role if membership else None


def has_partner_access(user, restaurant, *, min_role=RestaurantStaffRole.STAFF):
    role = get_partner_role(user, restaurant)
    return role is not None and ROLE_RANK[role] >= ROLE_RANK[min_role]


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


class IsRestaurantTeamMember(BasePermission):
    """Object-level check: the request user is the owner or an active
    MANAGER/STAFF member of the restaurant the object belongs to — i.e. any
    of the three partner-app roles from §4. Defaults to requiring STAFF
    (the lowest rung); pass `min_role` to the constructor for a one-off
    stricter check (e.g. in `get_permissions()`), or set `min_partner_role`
    as a class attribute on the view when the whole view needs the same
    floor for every method."""

    message = "You are not part of this restaurant's team."

    def __init__(self, min_role=None):
        self._min_role = min_role

    def has_object_permission(self, request, view, obj):
        min_role = self._min_role or getattr(view, "min_partner_role", RestaurantStaffRole.STAFF)
        restaurant = _resolve_restaurant(obj)
        role = get_partner_role(request.user, restaurant)
        if role is not None:
            # They're on the team, just ranked below what this action needs —
            # a clearer message than the generic "not part of this team".
            self.message = f"Your role ({role}) doesn't permit this action."
        return has_partner_access(request.user, restaurant, min_role=min_role)


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

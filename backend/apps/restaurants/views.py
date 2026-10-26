from django.conf import settings
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db.models import Sum
from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import permissions, status
from rest_framework.views import APIView

from apps.accounts.models import UserRole
from apps.accounts.permissions import IsAdminRole, IsRestaurantOwner
from apps.common.exceptions import ApplicationError
from apps.common.pagination import paginated_response
from apps.common.response import APIResponse

from . import services
from .models import (
    Favorite,
    Restaurant,
    RestaurantApprovalStatus,
    RestaurantCategory,
    RestaurantDocument,
    RestaurantImage,
    RestaurantStaff,
    RestaurantStaffRole,
)
from .permissions import IsRestaurantOwnerOfObject, IsRestaurantOwnerOrAdmin, IsRestaurantTeamMember, get_partner_role
from .serializers import (
    BusinessHoursBulkUpdateSerializer,
    BusinessHoursEntrySerializer,
    RestaurantCategorySerializer,
    RestaurantCreateUpdateSerializer,
    RestaurantDashboardSerializer,
    RestaurantDetailSerializer,
    RestaurantPartnerDetailSerializer,
    RestaurantDocumentReviewSerializer,
    RestaurantDocumentSerializer,
    RestaurantDocumentUploadSerializer,
    RestaurantImageSerializer,
    RestaurantImageUpdateSerializer,
    RestaurantImageUploadSerializer,
    RestaurantListSerializer,
    RestaurantPauseSerializer,
    RestaurantRatingBreakdownSerializer,
    RestaurantRejectSerializer,
    RestaurantStaffInviteSerializer,
    RestaurantStaffSerializer,
    RestaurantStaffUpdateSerializer,
    RestaurantStatusUpdateSerializer,
)


def _visible_restaurant_or_404(pk, user):
    """Public callers only ever see approved+active restaurants; the owner or an
    admin can see it in any state. Returns 404 (not 403) to avoid revealing
    existence of a restaurant the caller has no business knowing about."""
    restaurant = get_object_or_404(Restaurant, pk=pk)
    is_publicly_visible = restaurant.approval_status == RestaurantApprovalStatus.APPROVED and restaurant.is_active
    is_owner = bool(user and user.is_authenticated and restaurant.owner_id == user.id)
    is_admin = bool(user and user.is_authenticated and user.role == UserRole.ADMIN)
    if is_publicly_visible or is_owner or is_admin:
        return restaurant
    raise ApplicationError("Restaurant not found.", code="not_found", status_code=404)


@extend_schema(tags=["Restaurant Categories"], summary="List restaurant categories")
class RestaurantCategoryListCreateView(APIView):
    def get_permissions(self):
        if self.request.method == "POST":
            return [permissions.IsAuthenticated(), IsAdminRole()]
        return [permissions.AllowAny()]

    def get(self, request):
        queryset = RestaurantCategory.objects.all()
        if not (request.user.is_authenticated and request.user.role == UserRole.ADMIN):
            queryset = queryset.filter(is_active=True)
        return paginated_response(request, self, queryset, RestaurantCategorySerializer)

    @extend_schema(summary="Create a restaurant category (admin only)")
    def post(self, request):
        serializer = RestaurantCategorySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        category = serializer.save()
        return APIResponse(data=RestaurantCategorySerializer(category).data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["Restaurant Categories"])
class RestaurantCategoryDetailView(APIView):
    def get_permissions(self):
        if self.request.method == "GET":
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated(), IsAdminRole()]

    def get(self, request, pk):
        category = get_object_or_404(RestaurantCategory, pk=pk)
        return APIResponse(data=RestaurantCategorySerializer(category).data)

    @extend_schema(summary="Update a restaurant category (admin only)")
    def patch(self, request, pk):
        category = get_object_or_404(RestaurantCategory, pk=pk)
        serializer = RestaurantCategorySerializer(category, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return APIResponse(data=serializer.data)

    @extend_schema(summary="Delete a restaurant category (admin only)")
    def delete(self, request, pk):
        category = get_object_or_404(RestaurantCategory, pk=pk)
        category.delete()
        return APIResponse(data=None, status=status.HTTP_204_NO_CONTENT)


@extend_schema(tags=["Restaurants"])
class RestaurantListCreateView(APIView):
    def get_permissions(self):
        if self.request.method == "POST":
            return [permissions.IsAuthenticated(), IsRestaurantOwner()]
        return [permissions.AllowAny()]

    @extend_schema(
        summary="Browse approved, active restaurants",
        parameters=[
            OpenApiParameter("city", str), OpenApiParameter("category", str),
            OpenApiParameter("cuisine", str), OpenApiParameter("search", str),
            OpenApiParameter("lat", float), OpenApiParameter("lng", float),
            OpenApiParameter("only_open", bool),
            OpenApiParameter("veg_filter", str, description="'veg' or 'non_veg' — restaurants with at least one matching menu item"),
        ],
    )
    def get(self, request):
        queryset = Restaurant.objects.filter(approval_status=RestaurantApprovalStatus.APPROVED, is_active=True)
        params = request.query_params
        restaurants = services.search_restaurants(
            queryset,
            city=params.get("city"),
            category_slug=params.get("category"),
            cuisine=params.get("cuisine"),
            search=params.get("search"),
            lat=params.get("lat"),
            lng=params.get("lng"),
            only_open=params.get("only_open") in ("true", "1"),
            veg_filter=params.get("veg_filter"),
        )
        return paginated_response(request, self, restaurants, RestaurantListSerializer, context={"request": request})

    @extend_schema(summary="Register a new restaurant (owner only; starts pending approval)")
    def post(self, request):
        serializer = RestaurantCreateUpdateSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        restaurant = serializer.save()
        return APIResponse(data=RestaurantPartnerDetailSerializer(restaurant).data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["Restaurants"], summary="List the current restaurant owner's own restaurants")
class MyRestaurantsView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwner]

    def get(self, request):
        queryset = Restaurant.all_objects.filter(owner=request.user, is_deleted=False)
        return paginated_response(request, self, queryset, RestaurantPartnerDetailSerializer)


@extend_schema(tags=["Restaurants"], summary="List restaurants awaiting approval (admin only)")
class PendingApprovalListView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminRole]

    def get(self, request):
        queryset = Restaurant.objects.filter(approval_status=RestaurantApprovalStatus.PENDING)
        return paginated_response(request, self, queryset, RestaurantPartnerDetailSerializer)


@extend_schema(tags=["Restaurants"], summary="List every restaurant regardless of approval/active state (admin only)")
class AdminRestaurantListView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminRole]

    def get(self, request):
        queryset = Restaurant.objects.all().order_by("-created_at")
        approval_status = request.query_params.get("approval_status")
        if approval_status:
            queryset = queryset.filter(approval_status=approval_status)
        return paginated_response(request, self, queryset, RestaurantPartnerDetailSerializer)


@extend_schema(tags=["Restaurants"])
class RestaurantDetailView(APIView):
    def get_permissions(self):
        if self.request.method == "GET":
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated(), IsRestaurantOwnerOrAdmin()]

    @extend_schema(summary="Get restaurant details")
    def get(self, request, pk):
        restaurant = _visible_restaurant_or_404(pk, request.user)
        return APIResponse(data=RestaurantDetailSerializer(restaurant, context={"request": request}).data)

    @extend_schema(summary="Update restaurant details (owner or admin)")
    def patch(self, request, pk):
        restaurant = get_object_or_404(Restaurant, pk=pk)
        self.check_object_permissions(request, restaurant)
        serializer = RestaurantCreateUpdateSerializer(
            restaurant, data=request.data, partial=True, context={"request": request}
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return APIResponse(data=RestaurantPartnerDetailSerializer(restaurant).data)

    @extend_schema(summary="Soft-delete a restaurant (owner or admin)")
    def delete(self, request, pk):
        restaurant = get_object_or_404(Restaurant, pk=pk)
        self.check_object_permissions(request, restaurant)
        restaurant.delete()
        return APIResponse(data=None, status=status.HTTP_204_NO_CONTENT)


@extend_schema(tags=["Restaurants"], summary="Approve a pending restaurant (admin only)")
class RestaurantApproveView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminRole]

    def post(self, request, pk):
        restaurant = get_object_or_404(Restaurant, pk=pk)
        restaurant = services.approve_restaurant(restaurant, request.user)
        return APIResponse(data=RestaurantPartnerDetailSerializer(restaurant).data)


@extend_schema(tags=["Restaurants"], summary="Reject a pending restaurant (admin only)")
class RestaurantRejectView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminRole]

    def post(self, request, pk):
        restaurant = get_object_or_404(Restaurant, pk=pk)
        serializer = RestaurantRejectSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        restaurant = services.reject_restaurant(restaurant, request.user, serializer.validated_data["reason"])
        return APIResponse(data=RestaurantPartnerDetailSerializer(restaurant).data)


@extend_schema(tags=["Restaurants"], summary="Toggle a restaurant's active/accepting-orders status (owner only)")
class RestaurantStatusView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwnerOfObject]

    def patch(self, request, pk):
        restaurant = get_object_or_404(Restaurant, pk=pk)
        self.check_object_permissions(request, restaurant)
        serializer = RestaurantStatusUpdateSerializer(restaurant, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return APIResponse(data=RestaurantPartnerDetailSerializer(restaurant).data)


@extend_schema(tags=["Restaurants"], summary="Temporarily pause a restaurant (owner/manager)")
class RestaurantPauseView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantTeamMember]
    min_partner_role = RestaurantStaffRole.MANAGER

    def post(self, request, pk):
        restaurant = get_object_or_404(Restaurant, pk=pk)
        self.check_object_permissions(request, restaurant)
        serializer = RestaurantPauseSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        restaurant = services.pause_restaurant(
            restaurant,
            reason=serializer.validated_data["reason"],
            duration_minutes=serializer.validated_data.get("duration_minutes"),
        )
        return APIResponse(data=RestaurantPartnerDetailSerializer(restaurant).data)


@extend_schema(tags=["Restaurants"], summary="Resume a paused restaurant (owner/manager)")
class RestaurantResumeView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantTeamMember]
    min_partner_role = RestaurantStaffRole.MANAGER

    def post(self, request, pk):
        restaurant = get_object_or_404(Restaurant, pk=pk)
        self.check_object_permissions(request, restaurant)
        restaurant = services.resume_restaurant(restaurant)
        return APIResponse(data=RestaurantPartnerDetailSerializer(restaurant).data)


@extend_schema(tags=["Restaurant Staff"], summary="List or invite team members onto a restaurant (owner only)")
class RestaurantStaffListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwnerOfObject]

    def get(self, request, pk):
        restaurant = get_object_or_404(Restaurant, pk=pk)
        self.check_object_permissions(request, restaurant)
        queryset = restaurant.staff_members.filter(is_active=True).select_related("user")
        return paginated_response(request, self, queryset, RestaurantStaffSerializer)

    @extend_schema(summary="Invite a MANAGER or STAFF member by phone number (owner only)")
    def post(self, request, pk):
        restaurant = get_object_or_404(Restaurant, pk=pk)
        self.check_object_permissions(request, restaurant)
        serializer = RestaurantStaffInviteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        membership = services.invite_staff(
            restaurant,
            invited_by=request.user,
            **serializer.validated_data,
        )
        return APIResponse(data=RestaurantStaffSerializer(membership).data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["Restaurant Staff"], summary="Update or remove a team member (owner only)")
class RestaurantStaffDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwnerOfObject]

    def _get_membership(self, request, pk, staff_id):
        restaurant = get_object_or_404(Restaurant, pk=pk)
        self.check_object_permissions(request, restaurant)
        return get_object_or_404(RestaurantStaff, pk=staff_id, restaurant=restaurant)

    def patch(self, request, pk, staff_id):
        membership = self._get_membership(request, pk, staff_id)
        serializer = RestaurantStaffUpdateSerializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        for field, value in serializer.validated_data.items():
            setattr(membership, field, value)
        membership.save(update_fields=list(serializer.validated_data.keys()))
        return APIResponse(data=RestaurantStaffSerializer(membership).data)

    def delete(self, request, pk, staff_id):
        membership = self._get_membership(request, pk, staff_id)
        membership.delete()
        return APIResponse(data=None, status=status.HTTP_204_NO_CONTENT)


@extend_schema(tags=["Restaurants"], summary="Today's order/sales summary for the partner dashboard (owner/manager/staff)")
class RestaurantDashboardView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantTeamMember]

    def get(self, request, pk):
        from apps.orders.models import Order, OrderStatus  # local import: avoids a module-load-order dependency

        restaurant = get_object_or_404(Restaurant, pk=pk)
        self.check_object_permissions(request, restaurant)
        role = get_partner_role(request.user, restaurant)

        today_orders = Order.objects.filter(restaurant=restaurant, created_at__date=timezone.localdate())
        pending_statuses = [
            OrderStatus.PLACED, OrderStatus.ACCEPTED, OrderStatus.PREPARING,
            OrderStatus.READY_FOR_PICKUP, OrderStatus.OUT_FOR_DELIVERY,
        ]
        today_count = today_orders.count()
        completed_count = today_orders.filter(status=OrderStatus.DELIVERED).count()
        cancelled_count = today_orders.filter(status=OrderStatus.CANCELLED).count()
        sales = today_orders.exclude(status=OrderStatus.CANCELLED).aggregate(total=Sum("total_amount"))["total"] or 0

        payload = {
            "restaurant_name": restaurant.name,
            "display_status": restaurant.display_status,
            "today_orders_count": today_count,
            "pending_orders_count": today_orders.filter(status__in=pending_statuses).count(),
            "completed_orders_count": completed_count,
            "cancellation_rate_percent": round((cancelled_count / today_count * 100), 1) if today_count else 0.0,
            "rating": restaurant.average_rating,
        }
        if role in ("owner", RestaurantStaffRole.MANAGER):
            payload["today_sales"] = sales
            payload["average_order_value"] = round(sales / today_count, 2) if today_count else 0
        return APIResponse(data=RestaurantDashboardSerializer(payload).data)


@extend_schema(tags=["Restaurants"], summary="Get a restaurant's rating breakdown")
class RestaurantRatingView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request, pk):
        restaurant = _visible_restaurant_or_404(pk, request.user)
        breakdown = services.get_rating_breakdown(restaurant)
        return APIResponse(data=RestaurantRatingBreakdownSerializer(breakdown).data)


@extend_schema(tags=["Restaurant Images"])
class RestaurantImageListCreateView(APIView):
    def get_permissions(self):
        if self.request.method == "POST":
            return [permissions.IsAuthenticated(), IsRestaurantOwnerOfObject()]
        return [permissions.AllowAny()]

    def get(self, request, pk):
        restaurant = _visible_restaurant_or_404(pk, request.user)
        return APIResponse(data=RestaurantImageSerializer(restaurant.images.all(), many=True).data)

    @extend_schema(summary="Upload a restaurant image (owner only)", request=RestaurantImageUploadSerializer)
    def post(self, request, pk):
        restaurant = get_object_or_404(Restaurant, pk=pk)
        self.check_object_permissions(request, restaurant)
        serializer = RestaurantImageUploadSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        image = services.upload_restaurant_image(
            restaurant,
            serializer.validated_data["file"],
            caption=serializer.validated_data["caption"],
            is_primary=serializer.validated_data["is_primary"],
            max_size_bytes=settings.MAX_UPLOAD_SIZE_BYTES,
        )
        return APIResponse(data=RestaurantImageSerializer(image).data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["Restaurant Images"])
class RestaurantImageDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwnerOfObject]

    @extend_schema(summary="Update image caption/order/primary flag (owner only)")
    def patch(self, request, pk, image_id):
        image = get_object_or_404(RestaurantImage, pk=image_id, restaurant_id=pk)
        self.check_object_permissions(request, image)
        serializer = RestaurantImageUpdateSerializer(image, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return APIResponse(data=RestaurantImageSerializer(image).data)

    @extend_schema(summary="Delete a restaurant image (owner only)")
    def delete(self, request, pk, image_id):
        image = get_object_or_404(RestaurantImage, pk=image_id, restaurant_id=pk)
        self.check_object_permissions(request, image)
        services.delete_restaurant_image(image)
        return APIResponse(data=None, status=status.HTTP_204_NO_CONTENT)


@extend_schema(tags=["Restaurant Business Hours"])
class RestaurantBusinessHoursView(APIView):
    def get_permissions(self):
        if self.request.method == "GET":
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated(), IsRestaurantOwnerOfObject()]

    def get(self, request, pk):
        restaurant = _visible_restaurant_or_404(pk, request.user)
        return APIResponse(data=BusinessHoursEntrySerializer(restaurant.business_hours.all(), many=True).data)

    @extend_schema(summary="Replace the full weekly schedule (owner only)", request=BusinessHoursBulkUpdateSerializer)
    def put(self, request, pk):
        restaurant = get_object_or_404(Restaurant, pk=pk)
        self.check_object_permissions(request, restaurant)
        serializer = BusinessHoursBulkUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            hours = services.replace_business_hours(restaurant, serializer.validated_data["entries"])
        except DjangoValidationError as exc:
            raise ApplicationError("; ".join(exc.messages), code="invalid_business_hours") from exc
        return APIResponse(data=BusinessHoursEntrySerializer(hours, many=True).data)


@extend_schema(tags=["Restaurants"], summary="Favorite / unfavorite a restaurant")
class FavoriteToggleView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        restaurant = _visible_restaurant_or_404(pk, request.user)
        Favorite.objects.get_or_create(user=request.user, restaurant=restaurant)
        return APIResponse(data={"is_favorite": True})

    def delete(self, request, pk):
        restaurant = get_object_or_404(Restaurant, pk=pk)
        Favorite.objects.filter(user=request.user, restaurant=restaurant).delete()
        return APIResponse(data={"is_favorite": False})


@extend_schema(tags=["Restaurants"], summary="List the current user's favorite restaurants")
class FavoriteListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        restaurant_ids = Favorite.objects.filter(user=request.user).values_list("restaurant_id", flat=True)
        queryset = Restaurant.objects.filter(
            id__in=restaurant_ids, approval_status=RestaurantApprovalStatus.APPROVED, is_active=True
        )
        return paginated_response(request, self, queryset, RestaurantListSerializer, context={"request": request})


@extend_schema(tags=["Restaurant Documents"])
class RestaurantDocumentListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwnerOrAdmin]

    def get(self, request, pk):
        restaurant = get_object_or_404(Restaurant, pk=pk)
        self.check_object_permissions(request, restaurant)
        return APIResponse(data=RestaurantDocumentSerializer(restaurant.documents.all(), many=True).data)

    @extend_schema(summary="Upload a compliance document (owner only)", request=RestaurantDocumentUploadSerializer)
    def post(self, request, pk):
        restaurant = get_object_or_404(Restaurant, pk=pk)
        self.check_object_permissions(request, restaurant)
        serializer = RestaurantDocumentUploadSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        document = services.upload_restaurant_document(
            restaurant,
            serializer.validated_data["file"],
            serializer.validated_data["document_type"],
            max_size_bytes=settings.MAX_UPLOAD_SIZE_BYTES,
        )
        return APIResponse(data=RestaurantDocumentSerializer(document).data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["Restaurant Documents"], summary="Verify or reject a restaurant document (admin only)")
class RestaurantDocumentReviewView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminRole]

    def patch(self, request, pk, document_id):
        document = get_object_or_404(RestaurantDocument, pk=document_id, restaurant_id=pk)
        serializer = RestaurantDocumentReviewSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        document = services.review_restaurant_document(
            document, request.user, serializer.validated_data["status"], serializer.validated_data["rejection_reason"]
        )
        return APIResponse(data=RestaurantDocumentSerializer(document).data)

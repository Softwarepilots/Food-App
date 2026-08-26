from django.conf import settings
from django.core.exceptions import ValidationError as DjangoValidationError
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import permissions, status
from rest_framework.views import APIView

from apps.accounts.models import UserRole
from apps.accounts.permissions import IsAdminRole, IsRestaurantOwner
from apps.common.exceptions import ApplicationError
from apps.common.pagination import paginated_response
from apps.common.response import APIResponse

from . import services
from .models import Favorite, Restaurant, RestaurantApprovalStatus, RestaurantCategory, RestaurantDocument, RestaurantImage
from .permissions import IsRestaurantOwnerOfObject, IsRestaurantOwnerOrAdmin
from .serializers import (
    BusinessHoursBulkUpdateSerializer,
    BusinessHoursEntrySerializer,
    RestaurantCategorySerializer,
    RestaurantCreateUpdateSerializer,
    RestaurantDetailSerializer,
    RestaurantDocumentReviewSerializer,
    RestaurantDocumentSerializer,
    RestaurantDocumentUploadSerializer,
    RestaurantImageSerializer,
    RestaurantImageUpdateSerializer,
    RestaurantImageUploadSerializer,
    RestaurantListSerializer,
    RestaurantRatingBreakdownSerializer,
    RestaurantRejectSerializer,
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
        )
        return paginated_response(request, self, restaurants, RestaurantListSerializer, context={"request": request})

    @extend_schema(summary="Register a new restaurant (owner only; starts pending approval)")
    def post(self, request):
        serializer = RestaurantCreateUpdateSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        restaurant = serializer.save()
        return APIResponse(data=RestaurantDetailSerializer(restaurant).data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["Restaurants"], summary="List the current restaurant owner's own restaurants")
class MyRestaurantsView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwner]

    def get(self, request):
        queryset = Restaurant.all_objects.filter(owner=request.user, is_deleted=False)
        return paginated_response(request, self, queryset, RestaurantDetailSerializer)


@extend_schema(tags=["Restaurants"], summary="List restaurants awaiting approval (admin only)")
class PendingApprovalListView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminRole]

    def get(self, request):
        queryset = Restaurant.objects.filter(approval_status=RestaurantApprovalStatus.PENDING)
        return paginated_response(request, self, queryset, RestaurantDetailSerializer)


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
        return APIResponse(data=RestaurantDetailSerializer(restaurant).data)

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
        return APIResponse(data=RestaurantDetailSerializer(restaurant).data)


@extend_schema(tags=["Restaurants"], summary="Reject a pending restaurant (admin only)")
class RestaurantRejectView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminRole]

    def post(self, request, pk):
        restaurant = get_object_or_404(Restaurant, pk=pk)
        serializer = RestaurantRejectSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        restaurant = services.reject_restaurant(restaurant, request.user, serializer.validated_data["reason"])
        return APIResponse(data=RestaurantDetailSerializer(restaurant).data)


@extend_schema(tags=["Restaurants"], summary="Toggle a restaurant's active/accepting-orders status (owner only)")
class RestaurantStatusView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwnerOfObject]

    def patch(self, request, pk):
        restaurant = get_object_or_404(Restaurant, pk=pk)
        self.check_object_permissions(request, restaurant)
        serializer = RestaurantStatusUpdateSerializer(restaurant, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return APIResponse(data=RestaurantDetailSerializer(restaurant).data)


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

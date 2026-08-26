from django.conf import settings
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, status
from rest_framework.views import APIView

from apps.accounts.models import UserRole
from apps.common.exceptions import ApplicationError
from apps.common.pagination import paginated_response
from apps.common.response import APIResponse
from apps.restaurants.models import Restaurant, RestaurantApprovalStatus
from apps.restaurants.permissions import IsRestaurantOwnerOfObject, ReadOnlyOrIsRestaurantOwner

from . import services
from .models import Food, FoodAddon, FoodCategory, FoodDiscount, FoodImage, FoodVariant
from .serializers import (
    FoodAddonSerializer,
    FoodAvailabilitySerializer,
    FoodCategorySerializer,
    FoodCategoryWithFoodsSerializer,
    FoodCreateUpdateSerializer,
    FoodDetailSerializer,
    FoodDiscountSerializer,
    FoodImageSerializer,
    FoodImageUpdateSerializer,
    FoodImageUploadSerializer,
    FoodInventorySerializer,
    FoodListSerializer,
    FoodReviewCreateSerializer,
    FoodReviewSerializer,
    FoodVariantInventorySerializer,
    FoodVariantSerializer,
)


def _restaurant_or_404(restaurant_id):
    return get_object_or_404(Restaurant, pk=restaurant_id)


def _visible_restaurant_or_404(restaurant_id, user):
    restaurant = _restaurant_or_404(restaurant_id)
    is_publicly_visible = restaurant.approval_status == RestaurantApprovalStatus.APPROVED and restaurant.is_active
    is_owner = bool(user and user.is_authenticated and restaurant.owner_id == user.id)
    is_admin = bool(user and user.is_authenticated and user.role == UserRole.ADMIN)
    if is_publicly_visible or is_owner or is_admin:
        return restaurant
    raise ApplicationError("Restaurant not found.", code="not_found", status_code=404)


@extend_schema(tags=["Menu"], summary="Get a restaurant's published menu (public)")
class PublicMenuView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request, restaurant_id):
        restaurant = _visible_restaurant_or_404(restaurant_id, request.user)
        categories = restaurant.food_categories.all()
        data = FoodCategoryWithFoodsSerializer(categories, many=True, context={"request": request}).data
        uncategorized = restaurant.food_items.filter(category__isnull=True, is_available=True)
        payload = {"restaurant_id": str(restaurant.id), "categories": data}
        if uncategorized.exists():
            payload["uncategorized"] = FoodListSerializer(uncategorized, many=True, context={"request": request}).data
        return APIResponse(data=payload)


@extend_schema(tags=["Food Categories"])
class FoodCategoryListCreateView(APIView):
    def get_permissions(self):
        if self.request.method == "POST":
            return [permissions.IsAuthenticated(), IsRestaurantOwnerOfObject()]
        return [permissions.AllowAny()]

    def get(self, request, restaurant_id):
        restaurant = _visible_restaurant_or_404(restaurant_id, request.user)
        return APIResponse(data=FoodCategorySerializer(restaurant.food_categories.all(), many=True).data)

    @extend_schema(summary="Create a food category (owner only)")
    def post(self, request, restaurant_id):
        restaurant = _restaurant_or_404(restaurant_id)
        self.check_object_permissions(request, restaurant)
        serializer = FoodCategorySerializer(data=request.data, context={"restaurant": restaurant})
        serializer.is_valid(raise_exception=True)
        category = serializer.save(restaurant=restaurant)
        return APIResponse(data=FoodCategorySerializer(category).data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["Food Categories"])
class FoodCategoryDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwnerOfObject]

    def patch(self, request, restaurant_id, pk):
        category = get_object_or_404(FoodCategory, pk=pk, restaurant_id=restaurant_id)
        self.check_object_permissions(request, category)
        serializer = FoodCategorySerializer(category, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return APIResponse(data=serializer.data)

    def delete(self, request, restaurant_id, pk):
        category = get_object_or_404(FoodCategory, pk=pk, restaurant_id=restaurant_id)
        self.check_object_permissions(request, category)
        category.delete()
        return APIResponse(data=None, status=status.HTTP_204_NO_CONTENT)


@extend_schema(tags=["Foods"])
class FoodListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwnerOfObject]

    @extend_schema(summary="List all foods for a restaurant, including unavailable (owner/admin management view)")
    def get(self, request, restaurant_id):
        restaurant = _restaurant_or_404(restaurant_id)
        self.check_object_permissions(request, restaurant)
        queryset = restaurant.food_items.all()
        return paginated_response(request, self, queryset, FoodDetailSerializer)

    @extend_schema(summary="Create a food item (owner only)", request=FoodCreateUpdateSerializer)
    def post(self, request, restaurant_id):
        restaurant = _restaurant_or_404(restaurant_id)
        self.check_object_permissions(request, restaurant)
        serializer = FoodCreateUpdateSerializer(
            data=request.data, context={"request": request, "restaurant_id": restaurant.id}
        )
        serializer.is_valid(raise_exception=True)
        food = serializer.save()
        return APIResponse(data=FoodDetailSerializer(food).data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["Foods"])
class FoodDetailView(APIView):
    def get_permissions(self):
        if self.request.method == "GET":
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated(), IsRestaurantOwnerOfObject()]

    def get(self, request, restaurant_id, pk):
        food = get_object_or_404(Food, pk=pk, restaurant_id=restaurant_id)
        _visible_restaurant_or_404(restaurant_id, request.user)
        return APIResponse(data=FoodDetailSerializer(food).data)

    @extend_schema(summary="Update a food item (owner only)")
    def patch(self, request, restaurant_id, pk):
        food = get_object_or_404(Food, pk=pk, restaurant_id=restaurant_id)
        self.check_object_permissions(request, food)
        serializer = FoodCreateUpdateSerializer(
            food, data=request.data, partial=True, context={"request": request, "restaurant_id": food.restaurant_id}
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return APIResponse(data=FoodDetailSerializer(food).data)

    @extend_schema(summary="Delete a food item (owner only)")
    def delete(self, request, restaurant_id, pk):
        food = get_object_or_404(Food, pk=pk, restaurant_id=restaurant_id)
        self.check_object_permissions(request, food)
        food.delete()
        return APIResponse(data=None, status=status.HTTP_204_NO_CONTENT)


@extend_schema(tags=["Foods"], summary="Toggle a food item's availability (owner only)")
class FoodAvailabilityView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwnerOfObject]

    def patch(self, request, restaurant_id, pk):
        food = get_object_or_404(Food, pk=pk, restaurant_id=restaurant_id)
        self.check_object_permissions(request, food)
        serializer = FoodAvailabilitySerializer(food, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return APIResponse(data=FoodDetailSerializer(food).data)


@extend_schema(tags=["Foods"], summary="Update a food item's inventory settings (owner only)")
class FoodInventoryView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwnerOfObject]

    def patch(self, request, restaurant_id, pk):
        food = get_object_or_404(Food, pk=pk, restaurant_id=restaurant_id)
        self.check_object_permissions(request, food)
        serializer = FoodInventorySerializer(food, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return APIResponse(data=FoodDetailSerializer(food).data)


@extend_schema(tags=["Food Variants"])
class FoodVariantListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwnerOfObject]

    def get(self, request, food_id):
        food = get_object_or_404(Food, pk=food_id)
        self.check_object_permissions(request, food)
        return APIResponse(data=FoodVariantSerializer(food.variants.all(), many=True).data)

    @extend_schema(summary="Create a food variant (owner only)")
    def post(self, request, food_id):
        food = get_object_or_404(Food, pk=food_id)
        self.check_object_permissions(request, food)
        serializer = FoodVariantSerializer(data=request.data, context={"food": food})
        serializer.is_valid(raise_exception=True)
        variant = serializer.save(food=food)
        return APIResponse(data=FoodVariantSerializer(variant).data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["Food Variants"])
class FoodVariantDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwnerOfObject]

    def patch(self, request, food_id, pk):
        variant = get_object_or_404(FoodVariant, pk=pk, food_id=food_id)
        self.check_object_permissions(request, variant)
        serializer = FoodVariantSerializer(variant, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return APIResponse(data=serializer.data)

    def delete(self, request, food_id, pk):
        variant = get_object_or_404(FoodVariant, pk=pk, food_id=food_id)
        self.check_object_permissions(request, variant)
        variant.delete()
        return APIResponse(data=None, status=status.HTTP_204_NO_CONTENT)


@extend_schema(tags=["Food Variants"], summary="Update a variant's inventory settings (owner only)")
class FoodVariantInventoryView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwnerOfObject]

    def patch(self, request, food_id, pk):
        variant = get_object_or_404(FoodVariant, pk=pk, food_id=food_id)
        self.check_object_permissions(request, variant)
        serializer = FoodVariantInventorySerializer(variant, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return APIResponse(data=FoodVariantSerializer(variant).data)


@extend_schema(tags=["Food Addons"])
class FoodAddonListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwnerOfObject]

    def get(self, request, food_id):
        food = get_object_or_404(Food, pk=food_id)
        self.check_object_permissions(request, food)
        return APIResponse(data=FoodAddonSerializer(food.addons.all(), many=True).data)

    @extend_schema(summary="Create a food addon (owner only)")
    def post(self, request, food_id):
        food = get_object_or_404(Food, pk=food_id)
        self.check_object_permissions(request, food)
        serializer = FoodAddonSerializer(data=request.data, context={"food": food})
        serializer.is_valid(raise_exception=True)
        addon = serializer.save(food=food)
        return APIResponse(data=FoodAddonSerializer(addon).data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["Food Addons"])
class FoodAddonDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwnerOfObject]

    def patch(self, request, food_id, pk):
        addon = get_object_or_404(FoodAddon, pk=pk, food_id=food_id)
        self.check_object_permissions(request, addon)
        serializer = FoodAddonSerializer(addon, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return APIResponse(data=serializer.data)

    def delete(self, request, food_id, pk):
        addon = get_object_or_404(FoodAddon, pk=pk, food_id=food_id)
        self.check_object_permissions(request, addon)
        addon.delete()
        return APIResponse(data=None, status=status.HTTP_204_NO_CONTENT)


@extend_schema(tags=["Food Images"])
class FoodImageListCreateView(APIView):
    permission_classes = [ReadOnlyOrIsRestaurantOwner]

    def get(self, request, food_id):
        food = get_object_or_404(Food, pk=food_id)
        return APIResponse(data=FoodImageSerializer(food.images.all(), many=True).data)

    @extend_schema(summary="Upload a food image (owner only)", request=FoodImageUploadSerializer)
    def post(self, request, food_id):
        food = get_object_or_404(Food, pk=food_id)
        self.check_object_permissions(request, food)
        serializer = FoodImageUploadSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        image = services.upload_food_image(
            food,
            serializer.validated_data["file"],
            caption=serializer.validated_data["caption"],
            is_primary=serializer.validated_data["is_primary"],
            max_size_bytes=settings.MAX_UPLOAD_SIZE_BYTES,
        )
        return APIResponse(data=FoodImageSerializer(image).data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["Food Images"])
class FoodImageDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwnerOfObject]

    def patch(self, request, food_id, pk):
        image = get_object_or_404(FoodImage, pk=pk, food_id=food_id)
        self.check_object_permissions(request, image)
        serializer = FoodImageUpdateSerializer(image, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return APIResponse(data=FoodImageSerializer(image).data)

    def delete(self, request, food_id, pk):
        image = get_object_or_404(FoodImage, pk=pk, food_id=food_id)
        self.check_object_permissions(request, image)
        services.delete_food_image(image)
        return APIResponse(data=None, status=status.HTTP_204_NO_CONTENT)


@extend_schema(tags=["Food Discounts"])
class FoodDiscountListCreateView(APIView):
    permission_classes = [ReadOnlyOrIsRestaurantOwner]

    def get(self, request, food_id):
        food = get_object_or_404(Food, pk=food_id)
        return APIResponse(data=FoodDiscountSerializer(food.discounts.all(), many=True).data)

    @extend_schema(summary="Create a food discount (owner only)")
    def post(self, request, food_id):
        food = get_object_or_404(Food, pk=food_id)
        self.check_object_permissions(request, food)
        serializer = FoodDiscountSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        discount = serializer.save(food=food)
        return APIResponse(data=FoodDiscountSerializer(discount).data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["Food Discounts"])
class FoodDiscountDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwnerOfObject]

    def patch(self, request, food_id, pk):
        discount = get_object_or_404(FoodDiscount, pk=pk, food_id=food_id)
        self.check_object_permissions(request, discount)
        serializer = FoodDiscountSerializer(discount, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return APIResponse(data=serializer.data)

    def delete(self, request, food_id, pk):
        discount = get_object_or_404(FoodDiscount, pk=pk, food_id=food_id)
        self.check_object_permissions(request, discount)
        discount.delete()
        return APIResponse(data=None, status=status.HTTP_204_NO_CONTENT)


@extend_schema(tags=["Foods"], summary="List a food's reviews, or submit your own (one per user; resubmitting updates it)")
class FoodReviewListCreateView(APIView):
    def get_permissions(self):
        if self.request.method == "GET":
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    def get(self, request, food_id):
        food = get_object_or_404(Food, pk=food_id)
        queryset = food.reviews.all()
        return paginated_response(request, self, queryset, FoodReviewSerializer)

    def post(self, request, food_id):
        get_object_or_404(Food, pk=food_id)
        serializer = FoodReviewCreateSerializer(data=request.data, context={"request": request, "food_id": food_id})
        serializer.is_valid(raise_exception=True)
        review = serializer.save()
        return APIResponse(data=FoodReviewSerializer(review).data, status=status.HTTP_201_CREATED)

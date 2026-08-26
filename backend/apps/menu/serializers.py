from rest_framework import serializers

from . import services
from .models import Food, FoodAddon, FoodCategory, FoodDiscount, FoodImage, FoodReview, FoodVariant


class FoodCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodCategory
        fields = ("id", "name", "sort_order")

    def validate_name(self, value):
        restaurant = self.context.get("restaurant") or getattr(self.instance, "restaurant", None)
        if restaurant is None:
            return value
        queryset = restaurant.food_categories.filter(name__iexact=value)
        if self.instance:
            queryset = queryset.exclude(pk=self.instance.pk)
        if queryset.exists():
            raise serializers.ValidationError("A category with this name already exists for this restaurant.")
        return value


class FoodImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodImage
        fields = ("id", "image_url", "caption", "is_primary", "sort_order", "created_at")
        read_only_fields = ("id", "image_url", "created_at")


class FoodImageUploadSerializer(serializers.Serializer):
    file = serializers.ImageField()
    caption = serializers.CharField(max_length=150, required=False, allow_blank=True, default="")
    is_primary = serializers.BooleanField(required=False, default=False)


class FoodImageUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodImage
        fields = ("caption", "is_primary", "sort_order")


class FoodVariantSerializer(serializers.ModelSerializer):
    is_in_stock = serializers.BooleanField(read_only=True)
    is_orderable = serializers.BooleanField(read_only=True)

    class Meta:
        model = FoodVariant
        fields = (
            "id", "name", "price", "is_default", "is_available",
            "track_inventory", "stock_quantity", "low_stock_threshold",
            "is_in_stock", "is_orderable",
        )
        read_only_fields = ("id", "is_in_stock", "is_orderable")

    def validate_name(self, value):
        food = self.context.get("food") or getattr(self.instance, "food", None)
        if food is None:
            return value
        queryset = food.variants.filter(name__iexact=value)
        if self.instance:
            queryset = queryset.exclude(pk=self.instance.pk)
        if queryset.exists():
            raise serializers.ValidationError("A variant with this name already exists for this food item.")
        return value


class FoodAddonSerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodAddon
        fields = ("id", "name", "price", "is_available", "max_quantity")
        read_only_fields = ("id",)

    def validate_name(self, value):
        food = self.context.get("food") or getattr(self.instance, "food", None)
        if food is None:
            return value
        queryset = food.addons.filter(name__iexact=value)
        if self.instance:
            queryset = queryset.exclude(pk=self.instance.pk)
        if queryset.exists():
            raise serializers.ValidationError("An addon with this name already exists for this food item.")
        return value


class FoodDiscountSerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodDiscount
        fields = (
            "id", "discount_type", "value", "max_discount_amount",
            "valid_from", "valid_until", "is_active", "created_at",
        )
        read_only_fields = ("id", "created_at")

    def validate(self, attrs):
        valid_from = attrs.get("valid_from", getattr(self.instance, "valid_from", None))
        valid_until = attrs.get("valid_until", getattr(self.instance, "valid_until", None))
        if valid_from and valid_until and valid_until <= valid_from:
            raise serializers.ValidationError({"valid_until": "Must be after valid_from."})
        discount_type = attrs.get("discount_type", getattr(self.instance, "discount_type", None))
        value = attrs.get("value", getattr(self.instance, "value", None))
        if discount_type == "percentage" and value is not None and value > 100:
            raise serializers.ValidationError({"value": "Percentage discount cannot exceed 100."})
        return attrs


class FoodAvailabilitySerializer(serializers.ModelSerializer):
    class Meta:
        model = Food
        fields = ("is_available",)


class FoodInventorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Food
        fields = ("track_inventory", "stock_quantity", "low_stock_threshold")


class FoodVariantInventorySerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodVariant
        fields = ("track_inventory", "stock_quantity", "low_stock_threshold", "is_available")


class PricingSerializer(serializers.Serializer):
    unit_price = serializers.DecimalField(max_digits=8, decimal_places=2)
    discount_amount = serializers.DecimalField(max_digits=8, decimal_places=2)
    price_after_discount = serializers.DecimalField(max_digits=8, decimal_places=2)
    gst_rate = serializers.DecimalField(max_digits=5, decimal_places=2)
    gst_amount = serializers.DecimalField(max_digits=8, decimal_places=2)
    final_price = serializers.DecimalField(max_digits=8, decimal_places=2)


class FoodListSerializer(serializers.ModelSerializer):
    primary_image_url = serializers.SerializerMethodField()
    is_in_stock = serializers.BooleanField(read_only=True)
    is_orderable = serializers.BooleanField(read_only=True)
    pricing = serializers.SerializerMethodField()
    variants = FoodVariantSerializer(many=True, read_only=True)
    addons = FoodAddonSerializer(many=True, read_only=True)

    class Meta:
        model = Food
        fields = (
            "id", "category", "name", "description", "image_url", "primary_image_url",
            "food_type", "base_price", "gst_rate", "pricing", "is_available", "is_bestseller",
            "is_in_stock", "is_orderable", "calories", "preparation_time_minutes",
            "average_rating", "total_reviews", "variants", "addons",
        )

    def get_primary_image_url(self, obj):
        primary = next((image for image in obj.images.all() if image.is_primary), None)
        return primary.image_url if primary else obj.image_url

    def get_pricing(self, obj):
        return PricingSerializer(services.calculate_price(obj)).data


class FoodDetailSerializer(FoodListSerializer):
    images = FoodImageSerializer(many=True, read_only=True)
    discounts = serializers.SerializerMethodField()

    class Meta(FoodListSerializer.Meta):
        fields = FoodListSerializer.Meta.fields + (
            "restaurant", "track_inventory", "stock_quantity", "low_stock_threshold", "images", "discounts", "created_at",
        )
        read_only_fields = ("id", "restaurant", "created_at")

    def get_discounts(self, obj):
        return FoodDiscountSerializer(obj.discounts.filter(is_active=True), many=True).data


class FoodCreateUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Food
        fields = (
            "id", "category", "name", "description", "base_price", "gst_rate", "image_url",
            "food_type", "is_available", "is_bestseller", "calories", "preparation_time_minutes",
            "track_inventory", "stock_quantity", "low_stock_threshold",
        )
        read_only_fields = ("id",)

    def validate_category(self, value):
        if value is not None:
            request = self.context["request"]
            restaurant_id = self.context["restaurant_id"]
            if value.restaurant_id != restaurant_id:
                raise serializers.ValidationError("Category does not belong to this restaurant.")
        return value

    def create(self, validated_data):
        validated_data["restaurant_id"] = self.context["restaurant_id"]
        return super().create(validated_data)


class FoodCategoryWithFoodsSerializer(serializers.ModelSerializer):
    foods = serializers.SerializerMethodField()

    class Meta:
        model = FoodCategory
        fields = ("id", "name", "sort_order", "foods")

    def get_foods(self, obj):
        foods = [food for food in obj.food_items.all() if food.is_available]
        return FoodListSerializer(foods, many=True, context=self.context).data


class FoodReviewSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source="user.full_name", read_only=True)

    class Meta:
        model = FoodReview
        fields = ("id", "user_name", "rating", "comment", "created_at")
        read_only_fields = ("id", "user_name", "created_at")


class FoodReviewCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = FoodReview
        fields = ("id", "rating", "comment")
        read_only_fields = ("id",)

    def create(self, validated_data):
        validated_data["user"] = self.context["request"].user
        validated_data["food_id"] = self.context["food_id"]
        # One review per user per food — resubmitting updates the existing one.
        review, _created = FoodReview.objects.update_or_create(
            user=validated_data["user"],
            food_id=validated_data["food_id"],
            defaults={"rating": validated_data["rating"], "comment": validated_data.get("comment", "")},
        )
        return review

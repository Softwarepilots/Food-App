from rest_framework import serializers

from .models import (
    Restaurant,
    RestaurantBusinessHours,
    RestaurantCategory,
    RestaurantDocument,
    RestaurantDocumentStatus,
    RestaurantImage,
)


class RestaurantCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = RestaurantCategory
        fields = ("id", "name", "slug", "icon_url", "is_active", "sort_order")
        read_only_fields = ("id", "slug")


class RestaurantImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = RestaurantImage
        fields = ("id", "image_url", "caption", "is_primary", "sort_order", "created_at")
        read_only_fields = ("id", "image_url", "created_at")


class RestaurantImageUploadSerializer(serializers.Serializer):
    file = serializers.ImageField()
    caption = serializers.CharField(max_length=150, required=False, allow_blank=True, default="")
    is_primary = serializers.BooleanField(required=False, default=False)


class RestaurantImageUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = RestaurantImage
        fields = ("caption", "is_primary", "sort_order")


class BusinessHoursEntrySerializer(serializers.ModelSerializer):
    class Meta:
        model = RestaurantBusinessHours
        fields = ("day_of_week", "opening_time", "closing_time", "is_closed")


class BusinessHoursBulkUpdateSerializer(serializers.Serializer):
    entries = BusinessHoursEntrySerializer(many=True)

    def validate_entries(self, value):
        days = [entry["day_of_week"] for entry in value]
        if len(days) != len(set(days)):
            raise serializers.ValidationError("Each day of the week may only appear once.")
        return value


class RestaurantDocumentSerializer(serializers.ModelSerializer):
    class Meta:
        model = RestaurantDocument
        fields = (
            "id", "document_type", "file_url", "status", "rejection_reason",
            "reviewed_by", "reviewed_at", "created_at",
        )
        read_only_fields = fields


class RestaurantDocumentUploadSerializer(serializers.Serializer):
    file = serializers.FileField()
    document_type = serializers.ChoiceField(choices=RestaurantDocument._meta.get_field("document_type").choices)


class RestaurantDocumentReviewSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=[RestaurantDocumentStatus.VERIFIED, RestaurantDocumentStatus.REJECTED])
    rejection_reason = serializers.CharField(max_length=255, required=False, allow_blank=True, default="")

    def validate(self, attrs):
        if attrs["status"] == RestaurantDocumentStatus.REJECTED and not attrs.get("rejection_reason"):
            raise serializers.ValidationError({"rejection_reason": "A reason is required when rejecting a document."})
        return attrs


class RestaurantListSerializer(serializers.ModelSerializer):
    display_status = serializers.CharField(read_only=True)
    primary_image_url = serializers.SerializerMethodField()
    distance_km = serializers.SerializerMethodField()
    is_favorite = serializers.SerializerMethodField()

    class Meta:
        model = Restaurant
        fields = (
            "id", "name", "slug", "cover_image_url", "primary_image_url", "cuisine_tags", "city",
            "average_rating", "total_reviews", "avg_prep_time_minutes", "delivery_radius_km",
            "display_status", "distance_km", "is_favorite",
        )

    def get_primary_image_url(self, obj):
        primary = next((image for image in obj.images.all() if image.is_primary), None)
        return primary.image_url if primary else obj.cover_image_url

    def get_distance_km(self, obj):
        return getattr(obj, "distance_km", None)

    def get_is_favorite(self, obj):
        request = self.context.get("request")
        if not request or not request.user.is_authenticated:
            return False
        return obj.favorited_by.filter(user=request.user).exists()


class RestaurantDetailSerializer(serializers.ModelSerializer):
    display_status = serializers.CharField(read_only=True)
    is_open_now = serializers.BooleanField(read_only=True)
    categories = RestaurantCategorySerializer(many=True, read_only=True)
    images = RestaurantImageSerializer(many=True, read_only=True)
    business_hours = BusinessHoursEntrySerializer(many=True, read_only=True)
    distance_km = serializers.SerializerMethodField()
    is_favorite = serializers.SerializerMethodField()

    class Meta:
        model = Restaurant
        fields = (
            "id", "owner", "name", "slug", "description", "cover_image_url", "cuisine_tags", "categories",
            "address_line", "city", "latitude", "longitude", "delivery_radius_km",
            "avg_prep_time_minutes", "average_rating", "total_reviews",
            "is_active", "is_accepting_orders", "approval_status", "rejection_reason", "display_status",
            "is_open_now", "images", "business_hours", "distance_km", "is_favorite", "created_at",
        )
        read_only_fields = (
            "id", "owner", "average_rating", "total_reviews", "approval_status", "rejection_reason",
            "display_status", "is_open_now", "images", "business_hours", "created_at",
        )

    def get_distance_km(self, obj):
        return getattr(obj, "distance_km", None)

    def get_is_favorite(self, obj):
        request = self.context.get("request")
        if not request or not request.user.is_authenticated:
            return False
        return obj.favorited_by.filter(user=request.user).exists()


class RestaurantCreateUpdateSerializer(serializers.ModelSerializer):
    category_ids = serializers.PrimaryKeyRelatedField(
        source="categories", queryset=RestaurantCategory.objects.filter(is_active=True), many=True, required=False
    )

    class Meta:
        model = Restaurant
        fields = (
            "id", "name", "description", "cover_image_url", "cuisine_tags", "category_ids",
            "address_line", "city", "latitude", "longitude", "delivery_radius_km",
            "avg_prep_time_minutes", "is_active", "is_accepting_orders",
        )
        read_only_fields = ("id",)

    def create(self, validated_data):
        validated_data["owner"] = self.context["request"].user
        restaurant = super().create(validated_data)
        # New restaurants have no business hours until the owner sets their
        # own (there's no onboarding step that forces it) — without this
        # they'd show as permanently "closed" to customers with no obvious
        # reason why. Default to a reasonable 9am-10pm every day; the owner
        # can adjust it via PUT /restaurants/<id>/business-hours/.
        RestaurantBusinessHours.objects.bulk_create(
            RestaurantBusinessHours(
                restaurant=restaurant, day_of_week=day, opening_time="09:00", closing_time="22:00", is_closed=False
            )
            for day in range(7)
        )
        return restaurant


class RestaurantStatusUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Restaurant
        fields = ("is_active", "is_accepting_orders")


class RestaurantRejectSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=255)


class RestaurantRatingBreakdownSerializer(serializers.Serializer):
    average_rating = serializers.DecimalField(max_digits=3, decimal_places=2)
    total_reviews = serializers.IntegerField()
    breakdown = serializers.DictField(child=serializers.IntegerField())

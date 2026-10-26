from rest_framework import serializers

from apps.common.validators import fssai_number_validator, gst_number_validator, pan_number_validator, shop_license_number_validator

from .models import (
    Restaurant,
    RestaurantBusinessHours,
    RestaurantCategory,
    RestaurantDocument,
    RestaurantDocumentStatus,
    RestaurantImage,
    RestaurantStaff,
    RestaurantStaffRole,
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
        # Deliberately excludes bank_account_*/ifsc — this serializer's response
        # is also returned by the PUBLIC restaurant-detail GET (see
        # `_visible_restaurant_or_404` in views.py), so anything here is
        # visible to any customer browsing the restaurant page. Payout
        # details live only on `RestaurantPartnerDetailSerializer` below,
        # used solely from owner/manager-authenticated responses.
        fields = (
            "id", "owner", "name", "slug", "description", "cover_image_url", "cuisine_tags", "categories",
            "address_line", "city", "latitude", "longitude", "delivery_radius_km",
            "avg_prep_time_minutes", "average_rating", "total_reviews",
            "is_active", "is_accepting_orders", "pause_reason", "paused_until",
            "approval_status", "rejection_reason", "display_status",
            "is_open_now", "images", "business_hours", "distance_km", "is_favorite", "created_at",
            "fssai_number", "gst_number", "minimum_order_value", "packaging_policy",
        )
        read_only_fields = (
            "id", "owner", "average_rating", "total_reviews", "approval_status", "rejection_reason",
            "display_status", "is_open_now", "images", "business_hours", "created_at",
            "pause_reason", "paused_until",
        )

    def get_distance_km(self, obj):
        return getattr(obj, "distance_km", None)

    def get_is_favorite(self, obj):
        request = self.context.get("request")
        if not request or not request.user.is_authenticated:
            return False
        return obj.favorited_by.filter(user=request.user).exists()


class RestaurantPartnerDetailSerializer(RestaurantDetailSerializer):
    """Same as `RestaurantDetailSerializer` plus payout/bank details — only
    ever returned from endpoints already gated to the restaurant's own
    owner/manager (never the public GET)."""

    class Meta(RestaurantDetailSerializer.Meta):
        fields = RestaurantDetailSerializer.Meta.fields + (
            "pan_number", "shop_license_number",
            "bank_account_holder_name", "bank_account_number", "bank_ifsc_code",
        )


class RestaurantCreateUpdateSerializer(serializers.ModelSerializer):
    category_ids = serializers.PrimaryKeyRelatedField(
        source="categories", queryset=RestaurantCategory.objects.filter(is_active=True), many=True, required=False
    )
    # Required to *register* a restaurant (full create, not `partial=True`
    # updates — DRF's partial mode already relaxes `required` for PATCH, so
    # these don't block an owner from e.g. toggling `is_active` alone later).
    # PAN and FSSAI are legally mandatory for a food business in India; GST
    # stays optional (small businesses under the threshold don't need one).
    pan_number = serializers.CharField(max_length=10, validators=[pan_number_validator])
    fssai_number = serializers.CharField(max_length=14, validators=[fssai_number_validator])
    shop_license_number = serializers.CharField(max_length=30, validators=[shop_license_number_validator])
    gst_number = serializers.CharField(
        max_length=15, required=False, allow_blank=True, validators=[gst_number_validator]
    )

    class Meta:
        model = Restaurant
        fields = (
            "id", "name", "description", "cover_image_url", "cuisine_tags", "category_ids",
            "address_line", "city", "latitude", "longitude", "delivery_radius_km",
            "avg_prep_time_minutes", "is_active", "is_accepting_orders",
            "pan_number", "fssai_number", "gst_number", "shop_license_number",
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


class RestaurantPauseReason(serializers.ChoiceField):
    def __init__(self, **kwargs):
        super().__init__(
            choices=["kitchen_busy", "staff_unavailable", "maintenance", "power_issue", "other"], **kwargs
        )


class RestaurantPauseSerializer(serializers.Serializer):
    reason = RestaurantPauseReason()
    # Minutes to stay paused for; omit for "until manually enabled".
    duration_minutes = serializers.ChoiceField(choices=[30, 60, 120], required=False, allow_null=True)


class RestaurantStaffSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(source="user.full_name", read_only=True)
    phone_number = serializers.CharField(source="user.phone_number", read_only=True)
    email = serializers.EmailField(source="user.email", read_only=True)

    class Meta:
        model = RestaurantStaff
        fields = ("id", "full_name", "phone_number", "email", "role", "is_active", "created_at")
        read_only_fields = ("id", "created_at")


class RestaurantStaffInviteSerializer(serializers.Serializer):
    full_name = serializers.CharField(max_length=150)
    phone_number = serializers.CharField(max_length=15)
    email = serializers.EmailField(required=False, allow_blank=True)
    role = serializers.ChoiceField(choices=RestaurantStaffRole.choices)


class RestaurantStaffUpdateSerializer(serializers.Serializer):
    role = serializers.ChoiceField(choices=RestaurantStaffRole.choices, required=False)
    is_active = serializers.BooleanField(required=False)


class RestaurantDashboardSerializer(serializers.Serializer):
    """§5/§20 dashboard summary. `today_sales`/`average_order_value` are
    omitted (not just zeroed) for STAFF callers — financial figures aren't
    part of their role per §4."""

    restaurant_name = serializers.CharField()
    display_status = serializers.CharField()
    today_orders_count = serializers.IntegerField()
    pending_orders_count = serializers.IntegerField()
    completed_orders_count = serializers.IntegerField()
    cancellation_rate_percent = serializers.FloatField()
    rating = serializers.DecimalField(max_digits=3, decimal_places=2)
    today_sales = serializers.DecimalField(max_digits=10, decimal_places=2, required=False)
    average_order_value = serializers.DecimalField(max_digits=10, decimal_places=2, required=False)

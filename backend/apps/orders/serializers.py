from datetime import timedelta

from rest_framework import serializers

from .models import Order, OrderItem, OrderStatus, Review

DELIVERY_BUFFER_MINUTES = 20


class OrderItemSerializer(serializers.ModelSerializer):
    food_name = serializers.CharField(source="food_name_snapshot")
    variant_name = serializers.SerializerMethodField()
    addon_names = serializers.SerializerMethodField()
    unit_price = serializers.DecimalField(source="unit_price_snapshot", max_digits=8, decimal_places=2)

    class Meta:
        model = OrderItem
        fields = ("id", "food_name", "variant_name", "addon_names", "quantity", "unit_price", "line_total", "notes")

    def get_variant_name(self, obj):
        return obj.variant_name_snapshot or None

    def get_addon_names(self, obj):
        return [addon["name"] for addon in (obj.addons_snapshot or [])]


class OrderSerializer(serializers.ModelSerializer):
    restaurant_id = serializers.UUIDField(read_only=True)
    restaurant_name = serializers.CharField(source="restaurant.name", read_only=True)
    restaurant_image_url = serializers.SerializerMethodField()
    items = OrderItemSerializer(many=True, read_only=True)
    estimated_delivery_at = serializers.SerializerMethodField()
    delivery_partner_name = serializers.SerializerMethodField()
    delivery_partner_phone = serializers.SerializerMethodField()
    payment_method = serializers.SerializerMethodField()
    customer_name = serializers.CharField(source="user.full_name", read_only=True)
    customer_phone = serializers.CharField(source="user.phone_number", read_only=True)

    class Meta:
        model = Order
        fields = (
            "id", "order_number", "restaurant_id", "restaurant_name", "restaurant_image_url", "items",
            "customer_name", "customer_phone", "delivery_address_text", "status", "payment_status", "payment_method",
            "subtotal", "delivery_fee", "tax_amount", "discount_amount", "total_amount", "notes",
            "created_at", "estimated_prep_minutes", "estimated_delivery_at", "accept_deadline",
            "delivery_partner_name", "delivery_partner_phone",
        )

    def get_restaurant_image_url(self, obj):
        primary = next((image for image in obj.restaurant.images.all() if image.is_primary), None)
        return primary.image_url if primary else obj.restaurant.cover_image_url

    def get_estimated_delivery_at(self, obj):
        if obj.delivered_at:
            return obj.delivered_at
        if obj.status == "cancelled":
            return None
        # Once the restaurant has given a real prep-time estimate (on accept),
        # that's more accurate than the restaurant's general average.
        prep_minutes = obj.estimated_prep_minutes or obj.restaurant.avg_prep_time_minutes
        base_time = obj.accepted_at or obj.created_at
        return base_time + timedelta(minutes=prep_minutes + DELIVERY_BUFFER_MINUTES)

    def get_delivery_partner_name(self, obj):
        return obj.delivery_partner.user.full_name if obj.delivery_partner_id else None

    def get_delivery_partner_phone(self, obj):
        return obj.delivery_partner.user.phone_number if obj.delivery_partner_id else None

    def get_payment_method(self, obj):
        payment = getattr(obj, "payment", None)
        return payment.method if payment else "cod"


class OrderItemInputSerializer(serializers.Serializer):
    food_id = serializers.UUIDField()
    variant_id = serializers.UUIDField(required=False, allow_null=True)
    addon_quantities = serializers.DictField(child=serializers.IntegerField(min_value=0), required=False)
    quantity = serializers.IntegerField(min_value=1)
    notes = serializers.CharField(max_length=255, required=False, allow_blank=True)


class OrderCreateSerializer(serializers.Serializer):
    restaurant_id = serializers.UUIDField()
    delivery_address_id = serializers.UUIDField()
    items = OrderItemInputSerializer(many=True)
    payment_method = serializers.ChoiceField(choices=["cod", "online"])
    notes = serializers.CharField(max_length=1000, required=False, allow_blank=True)


class OrderCancelSerializer(serializers.Serializer):
    reason = serializers.CharField(max_length=255, required=False, allow_blank=True)


class OrderStatusUpdateSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=OrderStatus.choices)
    # Required when accepting (§8's "Set preparation time" step — 15/20/25/30/
    # 40/45 min presets or a custom value, the client can offer whatever UI it
    # likes as long as it lands in this range); ignored for every other transition.
    prep_time_minutes = serializers.IntegerField(min_value=1, max_value=180, required=False)

    def validate(self, attrs):
        if attrs["status"] == OrderStatus.ACCEPTED and "prep_time_minutes" not in attrs:
            raise serializers.ValidationError({"prep_time_minutes": "Required when accepting an order."})
        return attrs


class ReviewSerializer(serializers.ModelSerializer):
    delivery_partner_name = serializers.SerializerMethodField()

    class Meta:
        model = Review
        fields = (
            "id", "restaurant", "order", "rating", "comment", "restaurant_reply",
            "delivery_partner", "delivery_partner_name", "delivery_rating", "created_at",
        )
        read_only_fields = ("id", "restaurant", "order", "restaurant_reply", "delivery_partner", "created_at")

    def get_delivery_partner_name(self, obj):
        return obj.delivery_partner.user.full_name if obj.delivery_partner_id else None


class ReviewCreateSerializer(serializers.Serializer):
    rating = serializers.IntegerField(min_value=1, max_value=5)
    comment = serializers.CharField(max_length=1000, required=False, allow_blank=True)
    # Only meaningful when the order actually had a rider assigned — the
    # service layer silently drops this if the order has no delivery_partner,
    # rather than erroring, since the client can't always know in advance.
    delivery_rating = serializers.IntegerField(min_value=1, max_value=5, required=False, allow_null=True)

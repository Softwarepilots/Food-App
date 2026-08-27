from datetime import timedelta

from rest_framework import serializers

from .models import Order, OrderItem, OrderStatus

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
            "created_at", "estimated_delivery_at", "delivery_partner_name", "delivery_partner_phone",
        )

    def get_restaurant_image_url(self, obj):
        primary = next((image for image in obj.restaurant.images.all() if image.is_primary), None)
        return primary.image_url if primary else obj.restaurant.cover_image_url

    def get_estimated_delivery_at(self, obj):
        if obj.delivered_at:
            return obj.delivered_at
        if obj.status == "cancelled":
            return None
        total_minutes = obj.restaurant.avg_prep_time_minutes + DELIVERY_BUFFER_MINUTES
        return obj.created_at + timedelta(minutes=total_minutes)

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

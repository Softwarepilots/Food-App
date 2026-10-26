from rest_framework import serializers

from .models import DeliveryPartner, DeliveryPartnerStatus, DeliveryShift


class DeliveryPartnerProfileSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(source="user.full_name", read_only=True)
    phone_number = serializers.CharField(source="user.phone_number", read_only=True)

    class Meta:
        model = DeliveryPartner
        fields = (
            "id", "full_name", "phone_number", "vehicle_type", "vehicle_number", "license_number",
            "status", "is_verified", "rating_avg", "total_deliveries", "created_at",
        )
        read_only_fields = ("id", "status", "is_verified", "rating_avg", "total_deliveries", "created_at")

    def create(self, validated_data):
        validated_data["user"] = self.context["request"].user
        return super().create(validated_data)


class DeliveryPartnerStatusUpdateSerializer(serializers.Serializer):
    # Deliberately excludes ON_DELIVERY — that's system-managed (set on accept, cleared on delivery).
    status = serializers.ChoiceField(choices=[DeliveryPartnerStatus.ONLINE, DeliveryPartnerStatus.OFFLINE])


class DeliveryShiftSerializer(serializers.ModelSerializer):
    booked_count = serializers.IntegerField(read_only=True)
    is_full = serializers.SerializerMethodField()
    is_booked_by_me = serializers.SerializerMethodField()

    class Meta:
        model = DeliveryShift
        fields = (
            "id", "date", "start_time", "end_time", "rate_min_per_hour", "rate_max_per_hour", "is_peak", "capacity",
            "booked_count", "is_full", "is_booked_by_me",
        )

    def get_is_full(self, obj):
        return obj.booked_count >= obj.capacity

    def get_is_booked_by_me(self, obj):
        partner = self.context.get("partner")
        if not partner:
            return False
        return obj.id in self.context.get("booked_shift_ids", set())

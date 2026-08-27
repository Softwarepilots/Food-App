from rest_framework import serializers

from .models import DeliveryPartner, DeliveryPartnerStatus


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

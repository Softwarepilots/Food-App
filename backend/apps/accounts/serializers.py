from django.contrib.auth.password_validation import validate_password
from django.contrib.auth.tokens import default_token_generator
from django.utils.encoding import force_str
from django.utils.http import urlsafe_base64_decode
from rest_framework import serializers
from rest_framework.validators import UniqueValidator
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from apps.common.validators import phone_number_validator

from .models import Address, User, UserRole
from .tokens import email_verification_token_generator


class AddressSerializer(serializers.ModelSerializer):
    class Meta:
        model = Address
        fields = (
            "id", "label", "address_line1", "address_line2", "city", "state", "pincode",
            "latitude", "longitude", "is_default", "created_at",
        )
        read_only_fields = ("id", "created_at")

    def create(self, validated_data):
        validated_data["user"] = self.context["request"].user
        return super().create(validated_data)


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = (
            "id",
            "email",
            "phone_number",
            "full_name",
            "role",
            "profile_image_url",
            "is_email_verified",
            "is_phone_verified",
            "is_active",
            "created_at",
        )
        read_only_fields = fields


class UserActiveStatusSerializer(serializers.Serializer):
    is_active = serializers.BooleanField()


class RegisterSerializer(serializers.ModelSerializer):
    # The model itself allows a blank email (customers register via phone+OTP
    # and never touch this serializer), but anyone registering *through* this
    # email+password endpoint needs one on file to ever log back in.
    email = serializers.EmailField(required=True, validators=[UniqueValidator(queryset=User.objects.all())])
    password = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ("email", "phone_number", "full_name", "role", "password", "password_confirm")

    def validate_role(self, value):
        if value == UserRole.ADMIN:
            raise serializers.ValidationError("Admin accounts cannot be self-registered.")
        return value

    def validate(self, attrs):
        password = attrs.get("password")
        if password != attrs.pop("password_confirm", None):
            raise serializers.ValidationError({"password_confirm": "Passwords do not match."})
        temp_user = User(
            email=attrs.get("email"),
            full_name=attrs.get("full_name"),
            phone_number=attrs.get("phone_number"),
        )
        validate_password(password, user=temp_user)
        return attrs

    def create(self, validated_data):
        password = validated_data.pop("password")
        return User.objects.create_user(password=password, **validated_data)


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token["role"] = user.role
        token["full_name"] = user.full_name
        token["email"] = user.email or ""
        return token

    def validate(self, attrs):
        data = super().validate(attrs)
        data["user"] = UserSerializer(self.user).data
        return data


class EmailLoginSerializer(serializers.Serializer):
    """Email+password login — used by non-customer roles (restaurant owners,
    admins) that register through `RegisterSerializer`. Deliberately doesn't
    go through SimpleJWT's `TokenObtainPairSerializer`, since that always
    authenticates against `User.USERNAME_FIELD` (phone_number, for the
    customer app's phone+OTP flow), not email."""

    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        user = User.objects.filter(email__iexact=attrs["email"]).first()
        if user is None or not user.check_password(attrs["password"]):
            raise serializers.ValidationError("Invalid email or password.", code="invalid_credentials")
        if not user.is_active:
            raise serializers.ValidationError("This account is inactive.", code="inactive_account")
        attrs["user"] = user
        return attrs


class LogoutSerializer(serializers.Serializer):
    refresh = serializers.CharField()

    def validate_refresh(self, value):
        from rest_framework_simplejwt.exceptions import TokenError
        from rest_framework_simplejwt.tokens import RefreshToken

        try:
            self._token = RefreshToken(value)
        except TokenError as exc:
            raise serializers.ValidationError(str(exc))
        return value

    def save(self):
        self._token.blacklist()


class ForgotPasswordRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()


class ForgotPasswordConfirmSerializer(serializers.Serializer):
    uid = serializers.CharField()
    token = serializers.CharField()
    new_password = serializers.CharField(write_only=True, min_length=8)
    new_password_confirm = serializers.CharField(write_only=True, min_length=8)

    def validate(self, attrs):
        if attrs["new_password"] != attrs["new_password_confirm"]:
            raise serializers.ValidationError({"new_password_confirm": "Passwords do not match."})

        try:
            user_id = force_str(urlsafe_base64_decode(attrs["uid"]))
            user = User.objects.get(pk=user_id)
        except (User.DoesNotExist, ValueError, TypeError, OverflowError):
            raise serializers.ValidationError({"uid": "Invalid reset link."})

        if not default_token_generator.check_token(user, attrs["token"]):
            raise serializers.ValidationError({"token": "This reset link is invalid or has expired."})

        validate_password(attrs["new_password"], user=user)
        attrs["user"] = user
        return attrs

    def save(self):
        user = self.validated_data["user"]
        user.set_password(self.validated_data["new_password"])
        user.save(update_fields=["password"])
        return user


class EmailVerifyConfirmSerializer(serializers.Serializer):
    uid = serializers.CharField()
    token = serializers.CharField()

    def validate(self, attrs):
        try:
            user_id = force_str(urlsafe_base64_decode(attrs["uid"]))
            user = User.objects.get(pk=user_id)
        except (User.DoesNotExist, ValueError, TypeError, OverflowError):
            raise serializers.ValidationError({"uid": "Invalid verification link."})

        if user.is_email_verified:
            attrs["user"] = user
            attrs["already_verified"] = True
            return attrs

        if not email_verification_token_generator.check_token(user, attrs["token"]):
            raise serializers.ValidationError({"token": "This verification link is invalid or has expired."})

        attrs["user"] = user
        attrs["already_verified"] = False
        return attrs

    def save(self):
        user = self.validated_data["user"]
        if not self.validated_data["already_verified"]:
            user.is_email_verified = True
            user.save(update_fields=["is_email_verified"])
        return user


class PhoneVerifyConfirmSerializer(serializers.Serializer):
    otp = serializers.CharField(max_length=10)


class OTPLoginRequestSerializer(serializers.Serializer):
    phone_number = serializers.CharField(validators=[phone_number_validator])


class OTPLoginVerifySerializer(serializers.Serializer):
    phone_number = serializers.CharField(validators=[phone_number_validator])
    otp = serializers.CharField(max_length=10)
    full_name = serializers.CharField(max_length=150, required=False, allow_blank=False)

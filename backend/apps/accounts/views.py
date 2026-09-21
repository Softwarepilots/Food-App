from django.conf import settings
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, status
from rest_framework.generics import RetrieveAPIView
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from apps.common.exceptions import ApplicationError
from apps.common.pagination import paginated_response
from apps.common.response import APIResponse

from .models import Address, OTPPurpose, User, UserRole
from .permissions import IsAdminRole
from .serializers import (
    AddressSerializer,
    CustomTokenObtainPairSerializer,
    EmailLoginSerializer,
    EmailVerifyConfirmSerializer,
    ForgotPasswordConfirmSerializer,
    ForgotPasswordRequestSerializer,
    LogoutSerializer,
    OTPLoginRequestSerializer,
    OTPLoginVerifySerializer,
    PhoneVerifyConfirmSerializer,
    RegisterSerializer,
    UserActiveStatusSerializer,
    UserSerializer,
)
from .services import OTPService, get_or_create_user_by_phone, send_password_reset_email, send_sms, send_verification_email


@extend_schema(tags=["Auth"], summary="Register a new account (customer, restaurant owner or delivery partner)")
class RegisterView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "register"

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        send_verification_email(user)
        token = CustomTokenObtainPairSerializer.get_token(user)
        return APIResponse(
            data={
                "user": UserSerializer(user).data,
                "access": str(token.access_token),
                "refresh": str(token),
            },
            status=status.HTTP_201_CREATED,
        )


@extend_schema(tags=["Auth"], summary="Login with email and password (restaurant owners, admins)")
class LoginView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "login"

    def post(self, request):
        serializer = EmailLoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data["user"]
        token = CustomTokenObtainPairSerializer.get_token(user)
        return APIResponse(
            data={
                "user": UserSerializer(user).data,
                "access": str(token.access_token),
                "refresh": str(token),
            }
        )


@extend_schema(tags=["Admin"], summary="List all users, optionally filtered by role (admin only)")
class AdminUserListView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminRole]

    def get(self, request):
        queryset = User.objects.all().order_by("-created_at")
        role = request.query_params.get("role")
        if role:
            queryset = queryset.filter(role=role)
        search = request.query_params.get("search")
        if search:
            queryset = queryset.filter(full_name__icontains=search) | queryset.filter(email__icontains=search)
        return paginated_response(request, self, queryset, UserSerializer)


@extend_schema(tags=["Admin"], summary="Activate or deactivate a user account (admin only)")
class AdminUserStatusView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminRole]

    def patch(self, request, pk):
        user = get_object_or_404(User, pk=pk)
        serializer = UserActiveStatusSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user.is_active = serializer.validated_data["is_active"]
        user.save(update_fields=["is_active"])
        return APIResponse(data=UserSerializer(user).data)


@extend_schema(tags=["Auth"], summary="Logout by blacklisting the current refresh token")
class LogoutView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = LogoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return APIResponse(data=None, status=status.HTTP_205_RESET_CONTENT)


@extend_schema(tags=["Auth"], summary="Get the current authenticated user")
class MeView(RetrieveAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = UserSerializer

    def get_object(self):
        return self.request.user

    def retrieve(self, request, *args, **kwargs):
        serializer = self.get_serializer(self.get_object())
        return APIResponse(data=serializer.data)


@extend_schema(tags=["Auth"], summary="Request a password reset email")
class ForgotPasswordRequestView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "password_reset"

    def post(self, request):
        serializer = ForgotPasswordRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = User.objects.filter(email__iexact=serializer.validated_data["email"]).first()
        if user:
            send_password_reset_email(user)
        # Same response whether or not the email exists, to avoid leaking account existence.
        return APIResponse(data={"detail": "If an account with that email exists, a reset link has been sent."})


@extend_schema(tags=["Auth"], summary="Confirm a password reset using the emailed token")
class ForgotPasswordConfirmView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = ForgotPasswordConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return APIResponse(data={"detail": "Password has been reset successfully."})


@extend_schema(tags=["Auth"], summary="Resend the email verification link")
class EmailVerifyResendView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "password_reset"

    def post(self, request):
        if request.user.is_email_verified:
            return APIResponse(data={"detail": "Email is already verified."})
        send_verification_email(request.user)
        return APIResponse(data={"detail": "Verification email sent."})


@extend_schema(tags=["Auth"], summary="Confirm email verification using the emailed token")
class EmailVerifyConfirmView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = EmailVerifyConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return APIResponse(data={"detail": "Email verified successfully."})


@extend_schema(tags=["Auth"], summary="Request an OTP to verify the current user's phone number")
class PhoneVerifyRequestView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "otp"

    def post(self, request):
        user = request.user
        if user.is_phone_verified:
            return APIResponse(data={"detail": "Phone number is already verified."})

        _, code = OTPService.generate(user, OTPPurpose.PHONE_VERIFICATION, user.phone_number)
        send_sms(
            user.phone_number,
            f"Your verification code is {code}. It expires in {settings.OTP_EXPIRY_MINUTES} minutes.",
        )
        payload = {"detail": "OTP sent to your registered phone number."}
        if settings.DEBUG:
            payload["debug_otp"] = code
        return APIResponse(data=payload)


@extend_schema(tags=["Auth"], summary="Confirm phone verification with the received OTP")
class PhoneVerifyConfirmView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = PhoneVerifyConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        OTPService.verify(request.user, OTPPurpose.PHONE_VERIFICATION, serializer.validated_data["otp"])
        request.user.is_phone_verified = True
        request.user.save(update_fields=["is_phone_verified"])
        return APIResponse(data={"detail": "Phone number verified successfully."})


@extend_schema(tags=["Addresses"], summary="List or add a saved delivery address")
class AddressListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        queryset = request.user.addresses.all()
        return paginated_response(request, self, queryset, AddressSerializer)

    def post(self, request):
        serializer = AddressSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        address = serializer.save()
        return APIResponse(data=AddressSerializer(address).data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["Addresses"])
class AddressDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def _get_address(self, request, pk):
        return get_object_or_404(Address, pk=pk, user=request.user)

    @extend_schema(summary="Update a saved address")
    def patch(self, request, pk):
        address = self._get_address(request, pk)
        serializer = AddressSerializer(address, data=request.data, partial=True, context={"request": request})
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return APIResponse(data=serializer.data)

    @extend_schema(summary="Delete a saved address")
    def delete(self, request, pk):
        address = self._get_address(request, pk)
        address.delete()
        return APIResponse(data=None, status=status.HTTP_204_NO_CONTENT)


@extend_schema(
    tags=["Auth"],
    summary="Request a login/registration OTP for a phone number",
    description="Sends an OTP to `phone_number`. If no account exists for that number yet, one is "
    "silently provisioned (no separate registration step) — `is_new_user` in the response tells the "
    "client whether to collect a display name before/after verifying.",
)
class OTPLoginRequestView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "otp"

    def post(self, request):
        serializer = OTPLoginRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone_number = serializer.validated_data["phone_number"]

        user, _created = get_or_create_user_by_phone(phone_number)
        _, code = OTPService.generate(user, OTPPurpose.LOGIN, phone_number)
        send_sms(phone_number, f"Your Garuda login code is {code}. It expires in {settings.OTP_EXPIRY_MINUTES} minutes.")

        payload = {"detail": "OTP sent.", "is_new_user": not user.full_name}
        if settings.DEBUG:
            payload["debug_otp"] = code
        return APIResponse(data=payload)


@extend_schema(
    tags=["Auth"],
    summary="Verify a login/registration OTP and receive tokens",
    description="`full_name` is required the first time a number completes verification "
    "(i.e. when the account has no name on file yet); it's ignored on subsequent logins.",
)
class OTPLoginVerifyView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "otp"

    def post(self, request):
        serializer = OTPLoginVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone_number = serializer.validated_data["phone_number"]

        user = User.objects.filter(phone_number=phone_number).first()
        if not user:
            raise ApplicationError("No OTP was requested for this number.", code="otp_not_found", status_code=400)

        full_name = serializer.validated_data.get("full_name")
        if not full_name and not user.full_name:
            # Checked before consuming the OTP: failing here shouldn't force the
            # client to request (and the user to re-enter) a brand new code.
            raise ApplicationError(
                "Please provide your name to complete registration.", code="full_name_required", status_code=400
            )

        OTPService.verify(user, OTPPurpose.LOGIN, serializer.validated_data["otp"])

        update_fields = ["is_phone_verified"]
        user.is_phone_verified = True
        if full_name:
            user.full_name = full_name
            update_fields.append("full_name")
        user.save(update_fields=update_fields)

        token = CustomTokenObtainPairSerializer.get_token(user)
        return APIResponse(
            data={
                "user": UserSerializer(user).data,
                "access": str(token.access_token),
                "refresh": str(token),
            }
        )


def _existing_partner_user_or_404(phone_number):
    """Unlike the customer OTP flow, this deliberately does NOT silently
    provision a new account — logging into the partner app requires an
    account that already exists (self-registered as an owner, or invited
    as staff), so a wrong/unknown number gets a clear error instead of
    quietly creating an orphaned restaurant-owner-role account with no
    restaurant attached."""
    user = User.objects.filter(phone_number=phone_number, role=UserRole.RESTAURANT_OWNER).first()
    if not user:
        raise ApplicationError(
            "No partner account found for this number. Register from the partner app first.",
            code="partner_not_found",
            status_code=404,
        )
    return user


@extend_schema(
    tags=["Auth"],
    summary="Request a login OTP for an existing restaurant partner account",
    description="Unlike /auth/otp/request/, this never provisions a new account — the phone number "
    "must already belong to a restaurant owner or an invited staff member.",
)
class PartnerOTPRequestView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "otp"

    def post(self, request):
        serializer = OTPLoginRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone_number = serializer.validated_data["phone_number"]

        user = _existing_partner_user_or_404(phone_number)
        _, code = OTPService.generate(user, OTPPurpose.LOGIN, phone_number)
        send_sms(phone_number, f"Your Garuda Partner login code is {code}. It expires in {settings.OTP_EXPIRY_MINUTES} minutes.")

        payload = {"detail": "OTP sent."}
        if settings.DEBUG:
            payload["debug_otp"] = code
        return APIResponse(data=payload)


@extend_schema(tags=["Auth"], summary="Verify a restaurant partner login OTP and receive tokens")
class PartnerOTPVerifyView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "otp"

    def post(self, request):
        serializer = OTPLoginVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone_number = serializer.validated_data["phone_number"]

        user = _existing_partner_user_or_404(phone_number)
        OTPService.verify(user, OTPPurpose.LOGIN, serializer.validated_data["otp"])
        user.is_phone_verified = True
        user.save(update_fields=["is_phone_verified"])

        token = CustomTokenObtainPairSerializer.get_token(user)
        return APIResponse(
            data={
                "user": UserSerializer(user).data,
                "access": str(token.access_token),
                "refresh": str(token),
            }
        )

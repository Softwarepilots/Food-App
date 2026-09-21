from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView, TokenVerifyView

from . import views

app_name = "accounts"

urlpatterns = [
    path("register/", views.RegisterView.as_view(), name="register"),
    path("login/", views.LoginView.as_view(), name="login"),
    path("token/refresh/", TokenRefreshView.as_view(), name="token-refresh"),
    path("token/verify/", TokenVerifyView.as_view(), name="token-verify"),
    path("logout/", views.LogoutView.as_view(), name="logout"),
    path("me/", views.MeView.as_view(), name="me"),
    path("password/forgot/", views.ForgotPasswordRequestView.as_view(), name="password-forgot"),
    path("password/forgot/confirm/", views.ForgotPasswordConfirmView.as_view(), name="password-forgot-confirm"),
    path("email/verify/resend/", views.EmailVerifyResendView.as_view(), name="email-verify-resend"),
    path("email/verify/confirm/", views.EmailVerifyConfirmView.as_view(), name="email-verify-confirm"),
    path("phone/verify/request/", views.PhoneVerifyRequestView.as_view(), name="phone-verify-request"),
    path("phone/verify/confirm/", views.PhoneVerifyConfirmView.as_view(), name="phone-verify-confirm"),
    path("otp/request/", views.OTPLoginRequestView.as_view(), name="otp-request"),
    path("otp/verify/", views.OTPLoginVerifyView.as_view(), name="otp-verify"),
    path("partner-otp/request/", views.PartnerOTPRequestView.as_view(), name="partner-otp-request"),
    path("partner-otp/verify/", views.PartnerOTPVerifyView.as_view(), name="partner-otp-verify"),
    path("addresses/", views.AddressListCreateView.as_view(), name="address-list-create"),
    path("addresses/<uuid:pk>/", views.AddressDetailView.as_view(), name="address-detail"),
    path("admin/users/", views.AdminUserListView.as_view(), name="admin-user-list"),
    path("admin/users/<uuid:pk>/status/", views.AdminUserStatusView.as_view(), name="admin-user-status"),
]

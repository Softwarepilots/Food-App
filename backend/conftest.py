import pytest
from rest_framework.test import APIClient


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def make_user(db):
    from apps.accounts.models import UserRole

    def _make_user(
        email="user@test.com",
        password="S3cure!Pass123",
        full_name="Test User",
        phone_number="+919876543210",
        role=UserRole.CUSTOMER,
        **extra,
    ):
        from apps.accounts.models import User

        return User.objects.create_user(
            email=email, password=password, full_name=full_name, phone_number=phone_number, role=role, **extra
        )

    return _make_user


@pytest.fixture
def auth_header():
    def _auth_header(user):
        from apps.accounts.serializers import CustomTokenObtainPairSerializer

        token = CustomTokenObtainPairSerializer.get_token(user)
        return f"Bearer {token.access_token}"

    return _auth_header

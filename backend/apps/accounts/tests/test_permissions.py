import pytest
from django.test import RequestFactory

from apps.accounts.models import UserRole
from apps.accounts.permissions import (
    IsCustomer,
    IsDeliveryPartner,
    IsEmailVerified,
    IsPhoneVerified,
    IsRestaurantOwner,
)

pytestmark = pytest.mark.django_db

rf = RequestFactory()


def _request_as(user):
    request = rf.get("/")
    request.user = user
    return request


@pytest.mark.parametrize(
    ("permission_cls", "role", "expected"),
    [
        (IsCustomer, UserRole.CUSTOMER, True),
        (IsCustomer, UserRole.RESTAURANT_OWNER, False),
        (IsRestaurantOwner, UserRole.RESTAURANT_OWNER, True),
        (IsRestaurantOwner, UserRole.CUSTOMER, False),
        (IsDeliveryPartner, UserRole.DELIVERY_PARTNER, True),
        (IsDeliveryPartner, UserRole.CUSTOMER, False),
    ],
)
def test_role_permission(make_user, permission_cls, role, expected):
    user = make_user(email=f"{role}@test.com", phone_number="+919876500099", role=role)

    assert permission_cls().has_permission(_request_as(user), None) is expected


def test_role_permission_rejects_anonymous():
    from django.contrib.auth.models import AnonymousUser

    request = _request_as(AnonymousUser())

    assert IsCustomer().has_permission(request, None) is False


def test_is_email_verified_permission(make_user):
    verified = make_user(email="a@test.com", phone_number="+919876500001", is_email_verified=True)
    unverified = make_user(email="b@test.com", phone_number="+919876500002", is_email_verified=False)

    assert IsEmailVerified().has_permission(_request_as(verified), None) is True
    assert IsEmailVerified().has_permission(_request_as(unverified), None) is False


def test_is_phone_verified_permission(make_user):
    verified = make_user(email="a@test.com", phone_number="+919876500001", is_phone_verified=True)
    unverified = make_user(email="b@test.com", phone_number="+919876500002", is_phone_verified=False)

    assert IsPhoneVerified().has_permission(_request_as(verified), None) is True
    assert IsPhoneVerified().has_permission(_request_as(unverified), None) is False

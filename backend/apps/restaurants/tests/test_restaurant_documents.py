from unittest.mock import patch

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile

pytestmark = pytest.mark.django_db


def _documents_url(pk):
    return f"/api/v1/restaurants/{pk}/documents/"


def _review_url(pk, doc_id):
    return f"/api/v1/restaurants/{pk}/documents/{doc_id}/review/"


def _fake_pdf():
    return SimpleUploadedFile("license.pdf", b"%PDF-1.4 fake pdf content", content_type="application/pdf")


@patch("apps.restaurants.services.SupabaseStorageService.upload", return_value="https://storage.test/doc.pdf")
def test_owner_can_upload_document(mock_upload, api_client, make_restaurant, owner_user, auth_header):
    restaurant = make_restaurant(owner=owner_user)

    response = api_client.post(
        _documents_url(restaurant.id),
        {"file": _fake_pdf(), "document_type": "fssai_license"},
        format="multipart",
        HTTP_AUTHORIZATION=auth_header(owner_user),
    )

    assert response.status_code == 201
    body = response.json()["data"]
    assert body["status"] == "pending"
    assert body["document_type"] == "fssai_license"


def test_documents_list_not_public(api_client, make_restaurant):
    restaurant = make_restaurant()

    response = api_client.get(_documents_url(restaurant.id))

    assert response.status_code == 401


def test_other_owner_cannot_view_documents(api_client, make_restaurant, other_owner_user, auth_header):
    restaurant = make_restaurant()

    response = api_client.get(_documents_url(restaurant.id), HTTP_AUTHORIZATION=auth_header(other_owner_user))

    assert response.status_code == 403


def test_admin_can_view_documents(api_client, make_restaurant, admin_user, auth_header):
    restaurant = make_restaurant()

    response = api_client.get(_documents_url(restaurant.id), HTTP_AUTHORIZATION=auth_header(admin_user))

    assert response.status_code == 200


@patch("apps.restaurants.services.SupabaseStorageService.upload", return_value="https://storage.test/doc.pdf")
def test_admin_can_verify_document(mock_upload, api_client, make_restaurant, owner_user, admin_user, auth_header):
    restaurant = make_restaurant(owner=owner_user)
    document = api_client.post(
        _documents_url(restaurant.id), {"file": _fake_pdf(), "document_type": "pan_card"},
        format="multipart", HTTP_AUTHORIZATION=auth_header(owner_user),
    ).json()["data"]

    response = api_client.patch(
        _review_url(restaurant.id, document["id"]), {"status": "verified"}, format="json",
        HTTP_AUTHORIZATION=auth_header(admin_user),
    )

    assert response.status_code == 200
    assert response.json()["data"]["status"] == "verified"


@patch("apps.restaurants.services.SupabaseStorageService.upload", return_value="https://storage.test/doc.pdf")
def test_rejecting_document_requires_reason(mock_upload, api_client, make_restaurant, owner_user, admin_user, auth_header):
    restaurant = make_restaurant(owner=owner_user)
    document = api_client.post(
        _documents_url(restaurant.id), {"file": _fake_pdf(), "document_type": "pan_card"},
        format="multipart", HTTP_AUTHORIZATION=auth_header(owner_user),
    ).json()["data"]

    response = api_client.patch(
        _review_url(restaurant.id, document["id"]), {"status": "rejected"}, format="json",
        HTTP_AUTHORIZATION=auth_header(admin_user),
    )

    assert response.status_code == 400


def test_owner_cannot_review_own_document(api_client, make_restaurant, owner_user, auth_header):
    restaurant = make_restaurant(owner=owner_user)
    with patch("apps.restaurants.services.SupabaseStorageService.upload", return_value="https://storage.test/doc.pdf"):
        document = api_client.post(
            _documents_url(restaurant.id), {"file": _fake_pdf(), "document_type": "pan_card"},
            format="multipart", HTTP_AUTHORIZATION=auth_header(owner_user),
        ).json()["data"]

    response = api_client.patch(
        _review_url(restaurant.id, document["id"]), {"status": "verified"}, format="json",
        HTTP_AUTHORIZATION=auth_header(owner_user),
    )

    assert response.status_code == 403

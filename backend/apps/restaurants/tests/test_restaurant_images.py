import io
from unittest.mock import patch

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image

pytestmark = pytest.mark.django_db


def _images_url(pk):
    return f"/api/v1/restaurants/{pk}/images/"


def _image_detail_url(pk, image_id):
    return f"/api/v1/restaurants/{pk}/images/{image_id}/"


def _fake_image_file(name="photo.jpg"):
    buffer = io.BytesIO()
    Image.new("RGB", (10, 10), color="red").save(buffer, format="JPEG")
    buffer.seek(0)
    return SimpleUploadedFile(name, buffer.read(), content_type="image/jpeg")


@patch("apps.restaurants.services.SupabaseStorageService.upload", return_value="https://storage.test/img.jpg")
def test_owner_can_upload_image(mock_upload, api_client, make_restaurant, owner_user, auth_header):
    restaurant = make_restaurant(owner=owner_user)

    response = api_client.post(
        _images_url(restaurant.id),
        {"file": _fake_image_file(), "caption": "Front view", "is_primary": "true"},
        format="multipart",
        HTTP_AUTHORIZATION=auth_header(owner_user),
    )

    assert response.status_code == 201
    body = response.json()["data"]
    assert body["image_url"] == "https://storage.test/img.jpg"
    assert body["is_primary"] is True
    mock_upload.assert_called_once()


def test_other_owner_cannot_upload_image(api_client, make_restaurant, other_owner_user, auth_header):
    restaurant = make_restaurant()

    response = api_client.post(
        _images_url(restaurant.id),
        {"file": _fake_image_file()},
        format="multipart",
        HTTP_AUTHORIZATION=auth_header(other_owner_user),
    )

    assert response.status_code == 403


@patch("apps.restaurants.services.SupabaseStorageService.upload", return_value="https://storage.test/img.jpg")
def test_second_primary_image_demotes_first(mock_upload, api_client, make_restaurant, owner_user, auth_header):
    restaurant = make_restaurant(owner=owner_user)
    header = auth_header(owner_user)

    first = api_client.post(
        _images_url(restaurant.id), {"file": _fake_image_file(), "is_primary": "true"},
        format="multipart", HTTP_AUTHORIZATION=header,
    ).json()["data"]
    api_client.post(
        _images_url(restaurant.id), {"file": _fake_image_file(), "is_primary": "true"},
        format="multipart", HTTP_AUTHORIZATION=header,
    )

    response = api_client.get(_images_url(restaurant.id))
    images = response.json()["data"]
    first_image = next(img for img in images if img["id"] == first["id"])
    assert first_image["is_primary"] is False


@patch("apps.restaurants.services.SupabaseStorageService.upload", return_value="https://storage.test/img.jpg")
@patch("apps.restaurants.services.SupabaseStorageService.delete")
def test_owner_can_delete_image(mock_delete, mock_upload, api_client, make_restaurant, owner_user, auth_header):
    restaurant = make_restaurant(owner=owner_user)
    header = auth_header(owner_user)
    image = api_client.post(
        _images_url(restaurant.id), {"file": _fake_image_file()}, format="multipart", HTTP_AUTHORIZATION=header
    ).json()["data"]

    response = api_client.delete(_image_detail_url(restaurant.id, image["id"]), HTTP_AUTHORIZATION=header)

    assert response.status_code == 204
    mock_delete.assert_called_once()
    assert not restaurant.images.filter(pk=image["id"]).exists()


def test_image_upload_rejects_oversized_file(api_client, make_restaurant, owner_user, auth_header, settings):
    settings.MAX_UPLOAD_SIZE_BYTES = 10  # absurdly small, guaranteed to trip
    restaurant = make_restaurant(owner=owner_user)

    with patch("apps.restaurants.services.SupabaseStorageService.upload") as mock_upload:
        response = api_client.post(
            _images_url(restaurant.id), {"file": _fake_image_file()}, format="multipart",
            HTTP_AUTHORIZATION=auth_header(owner_user),
        )

    assert response.status_code == 400
    mock_upload.assert_not_called()

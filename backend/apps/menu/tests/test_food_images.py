import io
from unittest.mock import patch

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image

pytestmark = pytest.mark.django_db


def _images_url(food_id):
    return f"/api/v1/menu/foods/{food_id}/images/"


def _detail_url(food_id, image_id):
    return f"/api/v1/menu/foods/{food_id}/images/{image_id}/"


def _fake_image_file(name="dish.jpg"):
    buffer = io.BytesIO()
    Image.new("RGB", (10, 10), color="green").save(buffer, format="JPEG")
    buffer.seek(0)
    return SimpleUploadedFile(name, buffer.read(), content_type="image/jpeg")


@patch("apps.menu.services.SupabaseStorageService.upload", return_value="https://storage.test/dish.jpg")
def test_owner_can_upload_food_image(mock_upload, api_client, make_food, owner_user, auth_header):
    food = make_food()

    response = api_client.post(
        _images_url(food.id),
        {"file": _fake_image_file(), "is_primary": "true"},
        format="multipart",
        HTTP_AUTHORIZATION=auth_header(owner_user),
    )

    assert response.status_code == 201
    assert response.json()["data"]["image_url"] == "https://storage.test/dish.jpg"
    mock_upload.assert_called_once()


def test_other_owner_cannot_upload_food_image(api_client, make_food, other_owner_user, auth_header):
    food = make_food()

    response = api_client.post(
        _images_url(food.id), {"file": _fake_image_file()}, format="multipart", HTTP_AUTHORIZATION=auth_header(other_owner_user)
    )

    assert response.status_code == 403


@patch("apps.menu.services.SupabaseStorageService.upload", return_value="https://storage.test/dish.jpg")
def test_second_primary_image_demotes_first(mock_upload, api_client, make_food, owner_user, auth_header):
    food = make_food()
    header = auth_header(owner_user)
    first = api_client.post(
        _images_url(food.id), {"file": _fake_image_file(), "is_primary": "true"}, format="multipart", HTTP_AUTHORIZATION=header
    ).json()["data"]
    api_client.post(
        _images_url(food.id), {"file": _fake_image_file(), "is_primary": "true"}, format="multipart", HTTP_AUTHORIZATION=header
    )

    response = api_client.get(_images_url(food.id))
    first_image = next(img for img in response.json()["data"] if img["id"] == first["id"])
    assert first_image["is_primary"] is False


@patch("apps.menu.services.SupabaseStorageService.upload", return_value="https://storage.test/dish.jpg")
@patch("apps.menu.services.SupabaseStorageService.delete")
def test_owner_can_delete_image(mock_delete, mock_upload, api_client, make_food, owner_user, auth_header):
    food = make_food()
    header = auth_header(owner_user)
    image = api_client.post(
        _images_url(food.id), {"file": _fake_image_file()}, format="multipart", HTTP_AUTHORIZATION=header
    ).json()["data"]

    response = api_client.delete(_detail_url(food.id, image["id"]), HTTP_AUTHORIZATION=header)

    assert response.status_code == 204
    mock_delete.assert_called_once()

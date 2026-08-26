import mimetypes
import os
import uuid

import requests
from django.conf import settings

from .exceptions import ApplicationError


class SupabaseStorageService:
    """Thin client over the Supabase Storage REST API.

    Kept deliberately small and mockable (per the project's integrations-layer
    convention) so callers — and tests — never need real Supabase credentials
    to exercise the upload/delete flow around it.
    """

    def __init__(self):
        self.base_url = settings.SUPABASE_URL.rstrip("/")
        self.bucket = settings.SUPABASE_STORAGE_BUCKET
        self.service_key = settings.SUPABASE_SERVICE_ROLE_KEY

    def upload(self, file, folder):
        """Upload a Django `UploadedFile` under `folder/` and return its public URL."""
        extension = os.path.splitext(file.name)[1]
        object_path = f"{folder}/{uuid.uuid4().hex}{extension}"
        content_type = file.content_type or mimetypes.guess_type(file.name)[0] or "application/octet-stream"

        response = requests.post(
            f"{self.base_url}/storage/v1/object/{self.bucket}/{object_path}",
            headers={
                "Authorization": f"Bearer {self.service_key}",
                "Content-Type": content_type,
            },
            data=file.read(),
            timeout=30,
        )
        if response.status_code not in (200, 201):
            raise ApplicationError(
                "Failed to upload file to storage. Please try again.",
                code="storage_upload_failed",
                status_code=502,
            )
        return f"{self.base_url}/storage/v1/object/public/{self.bucket}/{object_path}"

    def delete(self, file_url):
        """Delete a previously-uploaded file given its public URL. Best-effort —
        failures are swallowed so a storage hiccup never blocks the DB-side delete."""
        marker = f"/object/public/{self.bucket}/"
        if marker not in file_url:
            return
        object_path = file_url.split(marker, 1)[1]
        try:
            requests.delete(
                f"{self.base_url}/storage/v1/object/{self.bucket}/{object_path}",
                headers={"Authorization": f"Bearer {self.service_key}"},
                timeout=30,
            )
        except requests.RequestException:
            pass

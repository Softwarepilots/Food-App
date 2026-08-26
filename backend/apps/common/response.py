from rest_framework.response import Response


class APIResponse(Response):
    """Standard success envelope for every non-error API response.

    Shape: {"success": true, "data": <payload>, "meta": <optional>}
    Kept consistent with the error envelope produced by custom_exception_handler
    so mobile clients can branch on `success` alone.
    """

    def __init__(self, data=None, meta=None, status=200, **kwargs):
        payload = {"success": True, "data": data}
        if meta is not None:
            payload["meta"] = meta
        super().__init__(data=payload, status=status, **kwargs)

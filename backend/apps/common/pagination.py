from rest_framework.pagination import PageNumberPagination

from .response import APIResponse


class StandardResultsSetPagination(PageNumberPagination):
    """Default pagination for all list endpoints; clients may override page size via ?page_size=."""

    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100


def paginated_response(request, view, items, serializer_class, context=None):
    """Paginate a queryset/list and wrap it in the standard APIResponse envelope,
    with pagination metadata under `meta` rather than mixed into `data`."""
    paginator = StandardResultsSetPagination()
    page = paginator.paginate_queryset(items, request, view=view)
    serializer = serializer_class(page, many=True, context=context or {})
    return APIResponse(
        data=serializer.data,
        meta={
            "count": paginator.page.paginator.count,
            "next": paginator.get_next_link(),
            "previous": paginator.get_previous_link(),
        },
    )

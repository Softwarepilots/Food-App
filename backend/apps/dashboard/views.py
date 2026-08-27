from django.db.models import Count, Sum
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import permissions
from rest_framework.views import APIView

from apps.accounts.models import User, UserRole
from apps.accounts.permissions import IsAdminRole
from apps.common.response import APIResponse
from apps.delivery.models import DeliveryPartner, DeliveryPartnerStatus
from apps.orders.models import Order, OrderStatus
from apps.restaurants.models import Restaurant, RestaurantApprovalStatus


@extend_schema(tags=["Admin"], summary="Platform-wide summary counts for the admin dashboard home screen")
class DashboardStatsView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminRole]

    def get(self, request):
        today = timezone.now().date()

        users_by_role = dict(User.objects.values_list("role").annotate(count=Count("id")).order_by())
        restaurants_by_status = dict(
            Restaurant.objects.values_list("approval_status").annotate(count=Count("id")).order_by()
        )
        active_orders_count = Order.objects.exclude(
            status__in=[OrderStatus.DELIVERED, OrderStatus.CANCELLED]
        ).count()
        today_orders = Order.objects.filter(created_at__date=today)
        today_revenue = today_orders.filter(status=OrderStatus.DELIVERED).aggregate(total=Sum("total_amount"))["total"] or 0

        return APIResponse(
            data={
                "users": {
                    "customer": users_by_role.get(UserRole.CUSTOMER, 0),
                    "restaurant_owner": users_by_role.get(UserRole.RESTAURANT_OWNER, 0),
                    "delivery_partner": users_by_role.get(UserRole.DELIVERY_PARTNER, 0),
                    "admin": users_by_role.get(UserRole.ADMIN, 0),
                    "total": User.objects.count(),
                },
                "restaurants": {
                    "pending": restaurants_by_status.get(RestaurantApprovalStatus.PENDING, 0),
                    "approved": restaurants_by_status.get(RestaurantApprovalStatus.APPROVED, 0),
                    "rejected": restaurants_by_status.get(RestaurantApprovalStatus.REJECTED, 0),
                    "total": Restaurant.objects.count(),
                },
                "orders": {
                    "active": active_orders_count,
                    "today_count": today_orders.count(),
                    "today_revenue": str(today_revenue),
                    "total": Order.objects.count(),
                },
                "delivery": {
                    "online": DeliveryPartner.objects.filter(status=DeliveryPartnerStatus.ONLINE).count(),
                    "unverified": DeliveryPartner.objects.filter(is_verified=False).count(),
                    "total": DeliveryPartner.objects.count(),
                },
            }
        )

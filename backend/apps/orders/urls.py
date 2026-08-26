from django.urls import path

from . import views

app_name = "orders"

urlpatterns = [
    path("restaurant-orders/", views.RestaurantOrdersView.as_view(), name="restaurant-orders"),
    path("", views.OrderListCreateView.as_view(), name="list-create"),
    path("<uuid:pk>/", views.OrderDetailView.as_view(), name="detail"),
    path("<uuid:pk>/cancel/", views.OrderCancelView.as_view(), name="cancel"),
    path("<uuid:pk>/status/", views.OrderStatusUpdateView.as_view(), name="status-update"),
]

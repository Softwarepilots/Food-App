from django.urls import path

from . import views

app_name = "delivery"

urlpatterns = [
    path("partners/me/", views.DeliveryPartnerProfileView.as_view(), name="partner-profile"),
    path("partners/me/status/", views.DeliveryPartnerStatusView.as_view(), name="partner-status"),
    path("orders/available/", views.AvailableOrdersView.as_view(), name="orders-available"),
    path("orders/mine/", views.MyDeliveriesView.as_view(), name="orders-mine"),
    path("orders/<uuid:pk>/accept/", views.AcceptOrderView.as_view(), name="order-accept"),
    path("orders/<uuid:pk>/deliver/", views.MarkDeliveredView.as_view(), name="order-deliver"),
    path("admin/partners/", views.AdminDeliveryPartnerListView.as_view(), name="admin-partner-list"),
    path("admin/partners/<uuid:pk>/verify/", views.AdminDeliveryPartnerVerifyView.as_view(), name="admin-partner-verify"),
]

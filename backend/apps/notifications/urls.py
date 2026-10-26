from django.urls import path

from . import views

app_name = "notifications"

urlpatterns = [
    path("devices/register/", views.DeviceTokenRegisterView.as_view(), name="device-register"),
    path("devices/unregister/", views.DeviceTokenUnregisterView.as_view(), name="device-unregister"),
    path("", views.NotificationListView.as_view(), name="list"),
    path("<uuid:pk>/read/", views.NotificationMarkReadView.as_view(), name="mark-read"),
]

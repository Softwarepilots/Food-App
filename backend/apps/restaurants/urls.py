from django.urls import path

from . import views

app_name = "restaurants"

urlpatterns = [
    path("categories/", views.RestaurantCategoryListCreateView.as_view(), name="category-list"),
    path("categories/<uuid:pk>/", views.RestaurantCategoryDetailView.as_view(), name="category-detail"),
    path("mine/", views.MyRestaurantsView.as_view(), name="mine"),
    path("pending-approval/", views.PendingApprovalListView.as_view(), name="pending-approval"),
    path("admin/all/", views.AdminRestaurantListView.as_view(), name="admin-all"),
    path("favorites/", views.FavoriteListView.as_view(), name="favorite-list"),
    path("", views.RestaurantListCreateView.as_view(), name="list-create"),
    path("<uuid:pk>/", views.RestaurantDetailView.as_view(), name="detail"),
    path("<uuid:pk>/favorite/", views.FavoriteToggleView.as_view(), name="favorite-toggle"),
    path("<uuid:pk>/approve/", views.RestaurantApproveView.as_view(), name="approve"),
    path("<uuid:pk>/reject/", views.RestaurantRejectView.as_view(), name="reject"),
    path("<uuid:pk>/status/", views.RestaurantStatusView.as_view(), name="status"),
    path("<uuid:pk>/ratings/", views.RestaurantRatingView.as_view(), name="ratings"),
    path("<uuid:pk>/images/", views.RestaurantImageListCreateView.as_view(), name="image-list-create"),
    path("<uuid:pk>/images/<uuid:image_id>/", views.RestaurantImageDetailView.as_view(), name="image-detail"),
    path("<uuid:pk>/business-hours/", views.RestaurantBusinessHoursView.as_view(), name="business-hours"),
    path("<uuid:pk>/documents/", views.RestaurantDocumentListCreateView.as_view(), name="document-list-create"),
    path(
        "<uuid:pk>/documents/<uuid:document_id>/review/",
        views.RestaurantDocumentReviewView.as_view(),
        name="document-review",
    ),
]

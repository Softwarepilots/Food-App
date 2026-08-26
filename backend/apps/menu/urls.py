from django.urls import path

from . import views

app_name = "menu"

urlpatterns = [
    path("restaurants/<uuid:restaurant_id>/menu/", views.PublicMenuView.as_view(), name="public-menu"),
    path("restaurants/<uuid:restaurant_id>/categories/", views.FoodCategoryListCreateView.as_view(), name="category-list-create"),
    path("restaurants/<uuid:restaurant_id>/categories/<uuid:pk>/", views.FoodCategoryDetailView.as_view(), name="category-detail"),
    path("restaurants/<uuid:restaurant_id>/foods/", views.FoodListCreateView.as_view(), name="food-list-create"),
    path("restaurants/<uuid:restaurant_id>/foods/<uuid:pk>/", views.FoodDetailView.as_view(), name="food-detail"),
    path("restaurants/<uuid:restaurant_id>/foods/<uuid:pk>/availability/", views.FoodAvailabilityView.as_view(), name="food-availability"),
    path("restaurants/<uuid:restaurant_id>/foods/<uuid:pk>/inventory/", views.FoodInventoryView.as_view(), name="food-inventory"),
    path("foods/<uuid:food_id>/variants/", views.FoodVariantListCreateView.as_view(), name="variant-list-create"),
    path("foods/<uuid:food_id>/variants/<uuid:pk>/", views.FoodVariantDetailView.as_view(), name="variant-detail"),
    path("foods/<uuid:food_id>/variants/<uuid:pk>/inventory/", views.FoodVariantInventoryView.as_view(), name="variant-inventory"),
    path("foods/<uuid:food_id>/addons/", views.FoodAddonListCreateView.as_view(), name="addon-list-create"),
    path("foods/<uuid:food_id>/addons/<uuid:pk>/", views.FoodAddonDetailView.as_view(), name="addon-detail"),
    path("foods/<uuid:food_id>/images/", views.FoodImageListCreateView.as_view(), name="image-list-create"),
    path("foods/<uuid:food_id>/images/<uuid:pk>/", views.FoodImageDetailView.as_view(), name="image-detail"),
    path("foods/<uuid:food_id>/discounts/", views.FoodDiscountListCreateView.as_view(), name="discount-list-create"),
    path("foods/<uuid:food_id>/discounts/<uuid:pk>/", views.FoodDiscountDetailView.as_view(), name="discount-detail"),
    path("foods/<uuid:food_id>/reviews/", views.FoodReviewListCreateView.as_view(), name="review-list-create"),
]

from django.apps import AppConfig


class MenuConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.menu"
    label = "menu"
    verbose_name = "Menu"

    def ready(self):
        from . import signals  # noqa: F401

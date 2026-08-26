from django.apps import AppConfig


class CommonConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.common"
    label = "common"
    verbose_name = "Common"

    def ready(self):
        _patch_template_context_copy_for_py314()


def _patch_template_context_copy_for_py314():
    """Compatibility shim for running Django 5.0 on Python 3.14.

    `django.template.context.BaseContext.__copy__` does `copy(super())` —
    shallow-copying a bare `super` proxy object rather than `self`. That
    happened to work on the Python versions Django 5.0 targets (up to 3.12)
    but raises `AttributeError: 'super' object has no attribute 'dicts'...`
    under Python 3.14's `copy` module, breaking every admin page that
    involves template block inheritance (i.e. all of them).

    Remove this once the project moves to a Django version with native
    Python 3.14 support, or pins an older, officially-supported Python.
    """
    from django.template import context as django_context

    def _copy(self):
        duplicate = self.__class__.__new__(self.__class__)
        duplicate.__dict__.update(self.__dict__)
        duplicate.dicts = self.dicts[:]
        return duplicate

    django_context.BaseContext.__copy__ = _copy

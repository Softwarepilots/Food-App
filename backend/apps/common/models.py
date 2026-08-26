import uuid

from django.db import models
from django.utils import timezone


class UUIDPrimaryKeyModel(models.Model):
    """Swaps Django's default auto-incrementing integer PK for a UUID.

    UUID PKs avoid leaking row counts/order through the API and are safe to
    generate client-side before a row is persisted.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    class Meta:
        abstract = True


class TimeStampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class SoftDeleteQuerySet(models.QuerySet):
    def alive(self):
        return self.filter(is_deleted=False)

    def dead(self):
        return self.filter(is_deleted=True)

    def delete(self):
        """Bulk soft-delete: `Model.objects.filter(...).delete()` marks rows deleted
        instead of removing them, matching the per-instance `delete()` below."""
        return self.update(is_deleted=True, deleted_at=timezone.now())

    def hard_delete(self):
        return super().delete()


class SoftDeleteManager(models.Manager):
    """Default manager: excludes soft-deleted rows from every lookup."""

    def get_queryset(self):
        return SoftDeleteQuerySet(self.model, using=self._db).alive()


class AllObjectsManager(models.Manager):
    """Escape hatch manager: includes soft-deleted rows, for admin/audit use."""

    def get_queryset(self):
        return SoftDeleteQuerySet(self.model, using=self._db)


class SoftDeleteModel(models.Model):
    is_deleted = models.BooleanField(default=False, db_index=True)
    deleted_at = models.DateTimeField(null=True, blank=True)

    objects = SoftDeleteManager()
    all_objects = AllObjectsManager()

    class Meta:
        abstract = True

    def delete(self, using=None, keep_parents=False, hard=False):
        if hard:
            return super().delete(using=using, keep_parents=keep_parents)
        self.is_deleted = True
        self.deleted_at = timezone.now()
        self.save(using=using, update_fields=["is_deleted", "deleted_at"])
        return None

    def restore(self):
        self.is_deleted = False
        self.deleted_at = None
        self.save(update_fields=["is_deleted", "deleted_at"])


class BaseModel(UUIDPrimaryKeyModel, TimeStampedModel, SoftDeleteModel):
    """Combines the three mixins above. Every domain model in this project
    inherits from this instead of `models.Model` directly."""

    class Meta:
        abstract = True

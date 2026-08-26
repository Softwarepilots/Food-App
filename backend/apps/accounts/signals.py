from django.db.models.signals import pre_save
from django.dispatch import receiver

from .models import Address


@receiver(pre_save, sender=Address)
def enforce_single_default_address(sender, instance, **kwargs):
    """A user may have many addresses but at most one marked `is_default`.
    Setting a new default silently demotes the previous one."""
    if not instance.is_default:
        return
    Address.objects.filter(user_id=instance.user_id, is_default=True).exclude(pk=instance.pk).update(
        is_default=False
    )

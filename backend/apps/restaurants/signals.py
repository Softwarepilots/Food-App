from django.db.models.signals import post_save, pre_save
from django.dispatch import receiver

from .models import Restaurant, RestaurantApprovalStatus, RestaurantImage


@receiver(pre_save, sender=RestaurantImage)
def enforce_single_primary_image(sender, instance, **kwargs):
    """A restaurant may have many images but at most one marked `is_primary`."""
    if not instance.is_primary:
        return
    RestaurantImage.objects.filter(restaurant_id=instance.restaurant_id, is_primary=True).exclude(
        pk=instance.pk
    ).update(is_primary=False)


@receiver(pre_save, sender=Restaurant)
def _capture_previous_approval_status(sender, instance, **kwargs):
    if not instance.pk:
        instance._previous_approval_status = None
        return
    instance._previous_approval_status = (
        Restaurant.all_objects.filter(pk=instance.pk).values_list("approval_status", flat=True).first()
    )


@receiver(post_save, sender=Restaurant)
def notify_owner_on_approval_change(sender, instance, created, **kwargs):
    previous_status = getattr(instance, "_previous_approval_status", None)
    if created or previous_status == instance.approval_status:
        return
    if instance.approval_status not in (RestaurantApprovalStatus.APPROVED, RestaurantApprovalStatus.REJECTED):
        return

    from apps.notifications import services as notifications_services
    from apps.notifications.models import NotificationType

    if instance.approval_status == RestaurantApprovalStatus.APPROVED:
        body = f"Congratulations! {instance.name} has been approved and is now live."
    else:
        reason = f" Reason: {instance.rejection_reason}" if instance.rejection_reason else ""
        body = f"{instance.name} was not approved.{reason}"

    notifications_services.create_notification(
        user_id=instance.owner_id,
        notification_type=NotificationType.SYSTEM,
        title="Restaurant approval update",
        body=body,
    )

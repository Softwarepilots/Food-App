from .models import Notification


def create_notification(*, user_id, notification_type, title, body, order_id=None):
    return Notification.objects.create(
        user_id=user_id,
        notification_type=notification_type,
        title=title,
        body=body,
        order_id=order_id,
    )

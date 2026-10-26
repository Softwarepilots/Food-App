from . import push
from .models import DeviceToken, Notification


def register_device_token(user, *, token, platform):
    """Upserts a token. Tokens aren't unique per user — the same physical
    token can show up under a different user if someone logs out and a
    different account logs in on the same device/browser — so we always
    reassign ownership to whoever just registered it rather than erroring."""
    device_token, _ = DeviceToken.objects.update_or_create(
        token=token,
        defaults={"user": user, "platform": platform, "is_active": True},
    )
    return device_token


def unregister_device_token(user, *, token):
    DeviceToken.objects.filter(user=user, token=token).update(is_active=False)


def notify_user(user, *, title, body, notification_type, order=None, data=None):
    """Records an in-app Notification row and best-effort pushes it to every
    active device the user is registered on. The DB row is the source of
    truth (shows in the notification bell even if push silently failed);
    the push is a real-time nudge on top of it."""
    notification = Notification.objects.create(
        user=user, title=title, body=body, notification_type=notification_type, order=order
    )
    _push_to_user(user, title=title, body=body, data=data)
    return notification


def notify_users(users, *, title, body, notification_type, order=None, data=None):
    notifications = [
        Notification(user=user, title=title, body=body, notification_type=notification_type, order=order)
        for user in users
    ]
    Notification.objects.bulk_create(notifications)
    for user in users:
        _push_to_user(user, title=title, body=body, data=data)
    return notifications


def _push_to_user(user, *, title, body, data=None):
    tokens = list(DeviceToken.objects.filter(user=user, is_active=True).values_list("token", flat=True))
    dead_tokens = push.send_to_tokens(tokens, title=title, body=body, data=data)
    if dead_tokens:
        DeviceToken.objects.filter(token__in=dead_tokens).update(is_active=False)

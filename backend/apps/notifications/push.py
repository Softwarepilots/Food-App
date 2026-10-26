"""Thin wrapper around firebase-admin so the rest of the app never has to
check whether Firebase is actually configured — every function here is a
safe no-op (logged, not raised) until FIREBASE_CREDENTIALS_PATH points at a
real service-account file. Keeps local dev and CI working without secrets."""

import logging

from django.conf import settings

logger = logging.getLogger(__name__)

_firebase_app = None
_init_attempted = False


def _get_app():
    global _firebase_app, _init_attempted
    if _init_attempted:
        return _firebase_app
    _init_attempted = True

    if not settings.FIREBASE_CREDENTIALS_PATH:
        logger.warning("FIREBASE_CREDENTIALS_PATH not set — push notifications are disabled.")
        return None

    import firebase_admin
    from firebase_admin import credentials

    try:
        cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
        _firebase_app = firebase_admin.initialize_app(cred)
    except (FileNotFoundError, ValueError) as exc:
        logger.error("Failed to initialize Firebase app: %s", exc)
        _firebase_app = None
    return _firebase_app


def send_to_tokens(tokens, *, title, body, data=None):
    """Sends one push to each of `tokens`. Returns the set of tokens FCM
    reported as dead (unregistered/invalid) so callers can deactivate them —
    devices get reinstalled or tokens rotate, and there's no other signal
    that a stored token has gone stale."""
    if not tokens:
        return set()

    app = _get_app()
    if app is None:
        return set()

    from firebase_admin import messaging

    dead_tokens = set()
    for token in tokens:
        message = messaging.Message(
            token=token,
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
        )
        try:
            messaging.send(message, app=app)
        except messaging.UnregisteredError:
            dead_tokens.add(token)
        except Exception:
            logger.exception("Failed to send push notification to token %s...", token[:12])
    return dead_tokens

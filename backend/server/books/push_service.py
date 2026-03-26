import logging
import os
from pathlib import Path

from .models import PushDevice

logger = logging.getLogger(__name__)

_firebase_app = None


def send_notification_push(notification):
    app = _get_firebase_app()
    if app is None:
        return False

    try:
        from firebase_admin import messaging
    except ImportError:
        return False

    devices = PushDevice.objects.filter(
        student=notification.student,
        is_active=True,
    )

    sent_any = False
    for device in devices:
        try:
            messaging.send(
                messaging.Message(
                    token=device.token,
                    notification=messaging.Notification(
                        title=notification.title,
                        body=notification.message,
                    ),
                    data={
                        "notification_id": str(notification.id),
                        "notification_type": notification.notification_type,
                    },
                    android=messaging.AndroidConfig(
                        priority="high",
                        notification=messaging.AndroidNotification(
                            channel_id="library_updates",
                        ),
                    ),
                    apns=messaging.APNSConfig(
                        headers={"apns-priority": "10"},
                        payload=messaging.APNSPayload(
                            aps=messaging.Aps(
                                sound="default",
                                badge=1,
                            ),
                        ),
                    ),
                ),
                app=app,
            )
            sent_any = True
        except Exception as exc:  # noqa: BLE001
            error_text = str(exc).lower()
            if (
                "requested entity was not found" in error_text
                or "not a valid fcm registration token" in error_text
                or "registration token is not valid" in error_text
            ):
                device.is_active = False
                device.save(update_fields=["is_active", "last_seen_at"])
            logger.warning("Failed to send push notification: %s", exc)

    return sent_any


def _get_firebase_app():
    global _firebase_app

    if _firebase_app is not None:
        return _firebase_app

    service_account_path = (
        os.environ.get("FIREBASE_SERVICE_ACCOUNT_PATH", "").strip()
        or os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "").strip()
    )
    if not service_account_path:
        return None

    path = Path(service_account_path)
    if not path.exists():
        logger.warning("FIREBASE_SERVICE_ACCOUNT_PATH does not exist: %s", path)
        return None

    try:
        import firebase_admin
        from firebase_admin import credentials
    except ImportError:
        logger.warning("firebase_admin is not installed; push notifications disabled.")
        return None

    try:
        _firebase_app = firebase_admin.initialize_app(
            credentials.Certificate(str(path))
        )
    except ValueError:
        _firebase_app = firebase_admin.get_app()

    return _firebase_app

import logging
import warnings

from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone
from firebase_admin import exceptions as firebase_exceptions
from firebase_admin import messaging

from accounts.firebase import get_firebase_app
from .models import Notification, NotificationType
from .texts import render

logger = logging.getLogger(__name__)

# The Flutter app creates an Android notification channel with this id
ANDROID_CHANNEL_ID = 'colohouse_default'

REQUEST_TYPES = {
    NotificationType.HOUSING_REQUEST,
    NotificationType.REQUEST_ACCEPTED,
    NotificationType.REQUEST_DECLINED,
}


def wants_push(user, notification_type):
    """Respects the user's settings: push on/off, then requests / messages (never to a deactivated account)."""
    if not (user.is_active and user.push_enabled and user.fcm_token):
        return False
    if notification_type in REQUEST_TYPES:
        return user.notify_requests
    if notification_type == NotificationType.NEW_MESSAGE:
        return user.notify_messages
    return True


def notify(user, notification_type, data=None, group='', **values):
    """Saves the notification in the user's history (in their language) and sends the push
    once the current database transaction is committed (no push for an action that was rolled back).

    `group`: while unread, a notification of the same group is updated instead of adding a new one.
    """
    title, body = render(notification_type, user.language, **values)
    fields = {'title': title[:120], 'body': body[:300], 'data': data or {}, 'created_at': timezone.now()}

    notification = None
    if group:
        notification = Notification.objects.filter(
            user=user, type=notification_type, group=group, is_read=False
        ).first()
    if notification:
        for name, value in fields.items():
            setattr(notification, name, value)
        notification.save(update_fields=list(fields))
    else:
        notification = Notification.objects.create(user=user, type=notification_type, group=group, **fields)

    if wants_push(user, notification_type):
        transaction.on_commit(lambda: send_push(notification))
    return notification


def send_push(notification):
    """Sends one notification to the user's phone with Firebase Cloud Messaging.
    Never raises: a push problem must not break the user's action."""
    user = notification.user
    token = user.fcm_token
    if not token:
        return
    data = {key: str(value) for key, value in notification.data.items()}
    data.update({'type': notification.type, 'notification_id': str(notification.pk)})
    try:
        with warnings.catch_warnings():
            # firebase-admin 7.8 prefers installation ids (fid); registration tokens still work
            warnings.simplefilter('ignore', DeprecationWarning)
            message = messaging.Message(
                token=token,
                notification=messaging.Notification(title=notification.title, body=notification.body),
                data=data,
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        channel_id=ANDROID_CHANNEL_ID,
                        tag=notification.group or None,
                    ),
                ),
            )
        messaging.send(message, app=get_firebase_app())
    except messaging.UnregisteredError:
        _forget_token(user, token)
    except firebase_exceptions.InvalidArgumentError as error:
        if 'registration token' in str(error).lower():
            _forget_token(user, token)
        else:
            logger.warning('Push to user %s rejected: %s', user.pk, error)
    except Exception:
        # Firebase down, no key file, network error... the history entry is saved anyway
        logger.exception('Push to user %s failed', user.pk)


def _forget_token(user, token):
    """The phone uninstalled the app or the token expired: stop sending to it."""
    get_user_model().objects.filter(pk=user.pk, fcm_token=token).update(fcm_token='')

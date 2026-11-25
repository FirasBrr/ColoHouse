import logging
from pathlib import Path

import firebase_admin
from django.conf import settings
from firebase_admin import auth, credentials
from rest_framework.exceptions import APIException

logger = logging.getLogger(__name__)


class FirebaseUnavailable(APIException):
    status_code = 503
    default_detail = 'Firebase login is not available right now. Try again later.'
    default_code = 'firebase_unavailable'


class FirebaseLoginFailed(APIException):
    """401 for a bad Firebase login (DRF would turn AuthenticationFailed into 403 on this view)."""
    status_code = 401
    default_detail = 'Invalid or expired Firebase token. Log in again.'
    default_code = 'authentication_failed'


def get_firebase_app():
    """Starts the Firebase Admin SDK once, with the service account key (backend/firebase-key.json)."""
    try:
        return firebase_admin.get_app()
    except ValueError:
        pass

    key_path = Path(settings.FIREBASE_KEY_PATH)
    if not key_path.exists():
        raise FirebaseUnavailable('Firebase is not configured on the server (missing firebase-key.json).')
    try:
        cred = credentials.Certificate(key_path)
    except (ValueError, OSError) as error:
        # Wrong file (e.g. google-services.json) or a broken download: a server problem, not the user's
        logger.exception('Invalid Firebase key file %s: %s', key_path, error)
        raise FirebaseUnavailable('Firebase is not configured correctly on the server (invalid firebase-key.json).')
    try:
        return firebase_admin.initialize_app(cred)
    except ValueError:
        # Another request started the app at the same moment
        return firebase_admin.get_app()


def verify_id_token(id_token):
    """Checks the ID token the app got from FirebaseAuth and returns its claims (uid, email, name...).

    Raises auth.InvalidIdTokenError (bad / expired token) or FirebaseUnavailable (server problem).
    clock_skew_seconds tolerates a PC clock that is a few seconds off.
    """
    app = get_firebase_app()
    try:
        return auth.verify_id_token(id_token, app=app, clock_skew_seconds=10)
    except auth.CertificateFetchError:
        raise FirebaseUnavailable()
    except ValueError as error:
        # firebase_admin raises ValueError for configuration problems (e.g. no project id), never for a bad token
        logger.exception('Firebase token check failed: %s', error)
        raise FirebaseUnavailable()

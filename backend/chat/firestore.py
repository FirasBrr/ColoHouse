import logging

from google.api_core import exceptions as google_exceptions
from google.api_core.retry import Retry

from accounts.firebase import FirebaseUnavailable, firestore_client

logger = logging.getLogger(__name__)

COLLECTION = 'conversations'
# A Firestore problem fails in about 10 s (503) instead of blocking the request for minutes
TIMEOUT = 5
RETRY = Retry(timeout=10)


def _document(conversation):
    return firestore_client().collection(COLLECTION).document(str(conversation.firestore_id))


def sync_conversation(conversation):
    """Creates / updates the Firestore document of the chat.

    `participants` holds the Firebase uids of the two people (active accounts only): the security
    rules (firestore.rules) only let them read the chat and write messages. Called again when the
    chat is opened, so a user who logged in with Firebase later is added, and a deactivated one removed.
    """
    owner, sender = conversation.participants()
    listing = conversation.request.listing
    try:
        _document(conversation).set({
            'request_id': conversation.request_id,
            'listing_id': listing.id,
            'listing_title': listing.title,
            'participants': [user.firebase_uid for user in (owner, sender) if user.firebase_uid and user.is_active],
            'participant_ids': [owner.id, sender.id],
            'created_at': conversation.created_at,
        }, merge=True, retry=RETRY, timeout=TIMEOUT)
    except google_exceptions.GoogleAPIError as error:
        logger.exception('Firestore sync of conversation %s failed', conversation.pk)
        raise FirebaseUnavailable('The chat is not available right now. Try again later.') from error


def try_sync_conversation(conversation):
    """Same as sync_conversation but never raises (used right after a request is accepted)."""
    try:
        sync_conversation(conversation)
    except Exception:
        logger.exception('Could not create the Firestore chat of conversation %s', conversation.pk)


def get_message(conversation, message_id):
    """Reads one message written by the app in Firestore; None if it does not exist."""
    try:
        snapshot = _document(conversation).collection('messages').document(message_id).get(
            retry=RETRY, timeout=TIMEOUT
        )
    except google_exceptions.GoogleAPIError as error:
        logger.exception('Firestore read of message %s failed', message_id)
        raise FirebaseUnavailable('The chat is not available right now. Try again later.') from error
    return snapshot.to_dict() if snapshot.exists else None


def try_delete_conversation(firestore_id):
    """Deletes the chat and all its messages from Firestore (account deleted, request deleted...).
    Never raises."""
    try:
        client = firestore_client()
        client.recursive_delete(client.collection(COLLECTION).document(str(firestore_id)))
    except Exception:
        logger.exception('Could not delete the Firestore chat %s', firestore_id)

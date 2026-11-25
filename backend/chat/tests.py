from datetime import datetime, timezone as dt_timezone
from unittest.mock import MagicMock, patch

from django.test import TestCase
from django.urls import reverse
from google.api_core import exceptions as google_exceptions
from rest_framework.test import APIClient

from accounts.firebase import FirebaseUnavailable
from accounts.models import User
from housing.models import HousingListing, HousingRequest, RequestStatus
from notifications.models import Notification, NotificationType
from .firestore import sync_conversation, try_sync_conversation
from .models import Conversation

SENT_AT = datetime(2026, 11, 25, 18, 0, tzinfo=dt_timezone.utc)
LATER = datetime(2026, 11, 25, 18, 1, tzinfo=dt_timezone.utc)


def make_user(email, first_name, uid):
    return User.objects.create_user(
        email, 'StrongPass123!', first_name=first_name, last_name='Test', firebase_uid=uid
    )


class ChatTestCase(TestCase):
    def setUp(self):
        self.host = make_user('host@colohouse.com', 'Host', 'uid-host')
        self.student = make_user('student@colohouse.com', 'Student', 'uid-student')
        self.outsider = make_user('other@colohouse.com', 'Other', 'uid-other')
        self.listing = HousingListing.objects.create(
            owner=self.host, title='Studio in Tunis', description='Quiet.', rent=400, room_type='studio',
            address='12 Main street', latitude=36.8, longitude=10.18, available_from='2026-12-01',
        )
        self.request = HousingRequest.objects.create(
            listing=self.listing, sender=self.student, status=RequestStatus.ACCEPTED
        )
        self.conversation = Conversation.objects.create(request=self.request)

    def client_for(self, user):
        client = APIClient()
        client.force_authenticate(user=user)
        return client


class ConversationApiTests(ChatTestCase):
    def test_both_participants_see_the_chat(self):
        for user, other_name in ((self.host, 'Student'), (self.student, 'Host')):
            response = self.client_for(user).get(reverse('chat:conversations'))
            self.assertEqual(response.status_code, 200)
            self.assertEqual(len(response.data), 1)
            item = response.data[0]
            self.assertEqual(item['other_user']['first_name'], other_name)
            self.assertNotIn('email', item['other_user'])
            self.assertEqual(item['listing']['title'], 'Studio in Tunis')
            self.assertEqual(item['firestore_path'], f'conversations/{self.conversation.firestore_id}')

    def test_outsider_sees_nothing(self):
        response = self.client_for(self.outsider).get(reverse('chat:conversations'))
        self.assertEqual(response.data, [])

    @patch('chat.views.sync_conversation')
    def test_opening_the_chat_syncs_firestore(self, sync):
        response = self.client_for(self.student).get(reverse('chat:conversation_detail', args=[self.conversation.id]))
        self.assertEqual(response.status_code, 200)
        sync.assert_called_once_with(self.conversation)

    @patch('chat.views.sync_conversation')
    def test_opening_the_chat_marks_its_notifications_read(self, sync):
        from notifications.services import notify
        notify(self.student, NotificationType.NEW_MESSAGE, group=f'conversation-{self.conversation.id}',
               sender='Host', text='Hello')
        notify(self.student, NotificationType.REQUEST_DECLINED, owner='Host', listing='Other')
        self.client_for(self.student).get(reverse('chat:conversation_detail', args=[self.conversation.id]))
        self.assertEqual(list(Notification.objects.filter(is_read=False).values_list('type', flat=True)),
                         [NotificationType.REQUEST_DECLINED])

    @patch('chat.views.sync_conversation')
    def test_outsider_cannot_open_the_chat(self, sync):
        response = self.client_for(self.outsider).get(reverse('chat:conversation_detail', args=[self.conversation.id]))
        self.assertEqual(response.status_code, 404)
        sync.assert_not_called()

    @patch('chat.views.sync_conversation')
    def test_chat_needs_a_firebase_login(self, sync):
        self.student.firebase_uid = None
        self.student.save()
        response = self.client_for(self.student).get(reverse('chat:conversation_detail', args=[self.conversation.id]))
        self.assertEqual(response.status_code, 400)

    @patch('chat.firestore.firestore_client')
    def test_firestore_down_gives_503(self, client):
        client.return_value.collection.return_value.document.return_value.set.side_effect = (
            google_exceptions.ServiceUnavailable('down')
        )
        response = self.client_for(self.student).get(reverse('chat:conversation_detail', args=[self.conversation.id]))
        self.assertEqual(response.status_code, 503)

    def test_requests_show_their_conversation(self):
        response = self.client_for(self.student).get(reverse('housing:sent_requests'))
        self.assertEqual(response.data[0]['conversation_id'], self.conversation.id)


@patch('chat.views.get_message')
class MessageSentTests(ChatTestCase):
    def post(self, user, message_id='msg_1'):
        return self.client_for(user).post(
            reverse('chat:message_sent', args=[self.conversation.id]), {'message_id': message_id}, format='json'
        )

    def test_updates_the_chat_and_notifies_the_other_person(self, get_message):
        get_message.return_value = {'sender_uid': 'uid-student', 'text': 'Hello!', 'sent_at': SENT_AT}
        response = self.post(self.student)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data, {'notified': True})
        get_message.assert_called_once_with(self.conversation, 'msg_1')

        self.conversation.refresh_from_db()
        self.assertEqual(self.conversation.last_message, 'Hello!')
        self.assertEqual(self.conversation.last_message_at, SENT_AT)
        self.assertEqual(self.conversation.last_sender, self.student)

        notification = Notification.objects.get(user=self.host)
        self.assertEqual(notification.type, NotificationType.NEW_MESSAGE)
        self.assertEqual(notification.title, 'New message from Student')
        self.assertEqual(notification.body, 'Hello!')
        self.assertEqual(notification.data, {'screen': 'conversation', 'conversation_id': self.conversation.id})

    def test_same_message_is_notified_once(self, get_message):
        get_message.return_value = {'sender_uid': 'uid-student', 'text': 'Hello!', 'sent_at': SENT_AT}
        self.post(self.student)
        response = self.post(self.student)
        self.assertEqual(response.data, {'notified': False})
        self.assertEqual(get_message.call_count, 1)

    def test_several_messages_give_one_unread_notification(self, get_message):
        get_message.return_value = {'sender_uid': 'uid-student', 'text': 'Hello!', 'sent_at': SENT_AT}
        self.post(self.student, 'msg_1')
        get_message.return_value = {'sender_uid': 'uid-student', 'text': 'Still free?', 'sent_at': LATER}
        self.post(self.student, 'msg_2')
        self.assertEqual(Notification.objects.filter(user=self.host).count(), 1)
        self.assertEqual(Notification.objects.get(user=self.host).body, 'Still free?')

    def test_older_message_does_not_roll_back_or_notify_again(self, get_message):
        get_message.return_value = {'sender_uid': 'uid-student', 'text': 'Newest', 'sent_at': LATER}
        self.post(self.student, 'msg_2')
        get_message.return_value = {'sender_uid': 'uid-student', 'text': 'Older', 'sent_at': SENT_AT}
        response = self.post(self.student, 'msg_1')
        self.assertEqual(response.data, {'notified': False})
        self.conversation.refresh_from_db()
        self.assertEqual(self.conversation.last_message, 'Newest')
        self.assertEqual(Notification.objects.get(user=self.host).body, 'Newest')

    def test_missing_sent_at_uses_now(self, get_message):
        get_message.return_value = {'sender_uid': 'uid-student', 'text': 'Hi', 'sent_at': None}
        self.assertEqual(self.post(self.student).data, {'notified': True})
        self.conversation.refresh_from_db()
        self.assertIsNotNone(self.conversation.last_message_at)

    def test_cannot_notify_for_someone_elses_message(self, get_message):
        get_message.return_value = {'sender_uid': 'uid-host', 'text': 'Fake', 'sent_at': SENT_AT}
        response = self.post(self.student)
        self.assertEqual(response.status_code, 403)
        self.assertFalse(Notification.objects.exists())

    def test_unknown_message_is_rejected(self, get_message):
        get_message.return_value = None
        response = self.post(self.student)
        self.assertEqual(response.status_code, 400)
        self.assertIn('message_id', response.data)

    def test_invalid_message_id_is_rejected(self, get_message):
        response = self.post(self.student, '../other/doc')
        self.assertEqual(response.status_code, 400)
        get_message.assert_not_called()

    def test_outsider_gets_404(self, get_message):
        response = self.post(self.outsider)
        self.assertEqual(response.status_code, 404)
        get_message.assert_not_called()


class FirestoreSyncTests(ChatTestCase):
    @patch('chat.firestore.firestore_client')
    def test_document_has_both_firebase_uids(self, client):
        sync_conversation(self.conversation)
        collection = client.return_value.collection
        collection.assert_called_once_with('conversations')
        collection.return_value.document.assert_called_once_with(str(self.conversation.firestore_id))
        data, = collection.return_value.document.return_value.set.call_args.args
        self.assertEqual(data['participants'], ['uid-host', 'uid-student'])
        self.assertEqual(data['participant_ids'], [self.host.id, self.student.id])
        self.assertEqual(data['request_id'], self.request.id)
        kwargs = collection.return_value.document.return_value.set.call_args.kwargs
        self.assertTrue(kwargs['merge'])
        self.assertEqual(kwargs['timeout'], 5)
        self.assertIsNotNone(kwargs['retry'])

    @patch('chat.firestore.firestore_client')
    def test_deactivated_user_is_removed_from_participants(self, client):
        self.student.is_active = False
        sync_conversation(self.conversation)
        data, = client.return_value.collection.return_value.document.return_value.set.call_args.args
        self.assertEqual(data['participants'], ['uid-host'])

    def test_firestore_ids_are_random(self):
        other_request = HousingRequest.objects.create(listing=self.listing, sender=self.outsider, status=RequestStatus.ACCEPTED)
        other = Conversation.objects.create(request=other_request)
        self.assertNotEqual(other.firestore_id, self.conversation.firestore_id)
        self.assertNotEqual(str(other.firestore_id), str(other.pk))

    @patch('chat.firestore.firestore_client')
    def test_user_without_firebase_is_left_out_until_later(self, client):
        self.student.firebase_uid = None
        self.student.save()
        sync_conversation(self.conversation)
        data, = client.return_value.collection.return_value.document.return_value.set.call_args.args
        self.assertEqual(data['participants'], ['uid-host'])

    @patch('chat.firestore.firestore_client', side_effect=FirebaseUnavailable())
    def test_try_sync_never_raises(self, client):
        try_sync_conversation(self.conversation)

    @patch('chat.signals.try_delete_conversation')
    def test_deleting_an_account_erases_its_chats_from_firestore(self, delete):
        firestore_id = self.conversation.firestore_id
        with self.captureOnCommitCallbacks(execute=True):
            self.student.delete()
        self.assertFalse(Conversation.objects.exists())
        delete.assert_called_once_with(firestore_id)

    @patch('chat.signals.try_sync_conversation')
    def test_deactivating_a_user_resyncs_their_chats(self, sync):
        with self.captureOnCommitCallbacks(execute=True):
            self.student.is_active = False
            self.student.save()
        sync.assert_called_once()
        self.assertEqual(sync.call_args.args[0], self.conversation)

    @patch('chat.signals.try_sync_conversation')
    def test_saving_an_active_user_does_not_resync(self, sync):
        with self.captureOnCommitCallbacks(execute=True):
            self.student.save()
        sync.assert_not_called()

    @patch('chat.firestore.firestore_client', new_callable=MagicMock)
    def test_google_error_becomes_firebase_unavailable(self, client):
        client.return_value.collection.return_value.document.return_value.set.side_effect = (
            google_exceptions.ServiceUnavailable('down')
        )
        with self.assertRaises(FirebaseUnavailable):
            sync_conversation(self.conversation)

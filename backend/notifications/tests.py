from unittest.mock import patch

from django.test import TestCase
from django.urls import reverse
from firebase_admin import exceptions as firebase_exceptions
from firebase_admin import messaging
from rest_framework.test import APIClient

from accounts.models import User
from chat.models import Conversation
from housing.models import HousingListing, HousingRequest, ListingStatus
from .models import Notification, NotificationType
from .services import notify


def make_user(email, **extra):
    return User.objects.create_user(email, 'StrongPass123!', first_name='Student', last_name='Test', **extra)


def make_listing(owner, **fields):
    data = {
        'title': 'Studio in Tunis', 'description': 'Quiet studio.', 'rent': 400, 'room_type': 'studio',
        'address': '12 Main street', 'latitude': 36.8, 'longitude': 10.18, 'available_from': '2026-12-01',
    }
    data.update(fields)
    return HousingListing.objects.create(owner=owner, **data)


@patch('notifications.services.messaging.send')
class NotifyTests(TestCase):
    def setUp(self):
        self.user = make_user('student@colohouse.com', fcm_token='device-token-1')

    def test_saved_in_the_user_language(self, send):
        self.user.language = 'fr'
        notification = notify(self.user, NotificationType.HOUSING_REQUEST, sender='Host', listing='Studio')
        self.assertEqual(notification.title, 'Nouvelle demande de logement')
        self.assertEqual(notification.body, 'Host souhaite louer « Studio ».')

    def test_arabic_text(self, send):
        self.user.language = 'ar'
        notification = notify(self.user, NotificationType.REQUEST_DECLINED, owner='Host', listing='Studio')
        self.assertEqual(notification.title, 'تم رفض الطلب')

    def test_push_sent_after_commit_with_data(self, send):
        with self.captureOnCommitCallbacks(execute=True):
            notification = notify(
                self.user, NotificationType.HOUSING_REQUEST,
                data={'screen': 'received_requests', 'request_id': 5}, sender='Host', listing='Studio',
            )
        send.assert_called_once()
        message = send.call_args.args[0]
        self.assertEqual(message.token, 'device-token-1')
        self.assertEqual(message.notification.title, 'New housing request')
        self.assertEqual(message.data, {
            'screen': 'received_requests', 'request_id': '5',
            'type': 'housing_request', 'notification_id': str(notification.pk),
        })
        self.assertEqual(message.android.notification.channel_id, 'colohouse_default')

    def test_no_push_before_commit(self, send):
        with self.captureOnCommitCallbacks(execute=False) as callbacks:
            notify(self.user, NotificationType.HOUSING_REQUEST, sender='Host', listing='Studio')
        self.assertEqual(len(callbacks), 1)
        send.assert_not_called()

    def test_no_push_when_push_disabled(self, send):
        self.user.push_enabled = False
        with self.captureOnCommitCallbacks(execute=True):
            notify(self.user, NotificationType.HOUSING_REQUEST, sender='Host', listing='Studio')
        send.assert_not_called()
        self.assertEqual(Notification.objects.count(), 1)

    def test_no_push_when_request_notifications_off(self, send):
        self.user.notify_requests = False
        with self.captureOnCommitCallbacks(execute=True):
            notify(self.user, NotificationType.REQUEST_ACCEPTED, owner='Host', listing='Studio')
        send.assert_not_called()

    def test_no_push_when_message_notifications_off(self, send):
        self.user.notify_messages = False
        with self.captureOnCommitCallbacks(execute=True):
            notify(self.user, NotificationType.NEW_MESSAGE, sender='Host', text='Hello')
        send.assert_not_called()

    def test_no_push_to_a_deactivated_account(self, send):
        self.user.is_active = False
        with self.captureOnCommitCallbacks(execute=True):
            notify(self.user, NotificationType.HOUSING_REQUEST, sender='Host', listing='Studio')
        send.assert_not_called()

    def test_long_names_are_cut_to_fit(self, send):
        notification = notify(self.user, NotificationType.NEW_MESSAGE, sender='A' * 200, text='Hi')
        self.assertEqual(len(notification.title), 120)

    def test_no_push_without_token(self, send):
        self.user.fcm_token = ''
        with self.captureOnCommitCallbacks(execute=True):
            notify(self.user, NotificationType.HOUSING_REQUEST, sender='Host', listing='Studio')
        send.assert_not_called()

    def test_unregistered_token_is_forgotten(self, send):
        send.side_effect = messaging.UnregisteredError('app uninstalled')
        with self.captureOnCommitCallbacks(execute=True):
            notify(self.user, NotificationType.HOUSING_REQUEST, sender='Host', listing='Studio')
        self.user.refresh_from_db()
        self.assertEqual(self.user.fcm_token, '')

    def test_invalid_token_is_forgotten(self, send):
        send.side_effect = firebase_exceptions.InvalidArgumentError(
            'The registration token is not a valid FCM registration token'
        )
        with self.captureOnCommitCallbacks(execute=True):
            notify(self.user, NotificationType.HOUSING_REQUEST, sender='Host', listing='Studio')
        self.user.refresh_from_db()
        self.assertEqual(self.user.fcm_token, '')

    def test_push_failure_never_breaks_the_action(self, send):
        send.side_effect = RuntimeError('network down')
        with self.captureOnCommitCallbacks(execute=True):
            notify(self.user, NotificationType.HOUSING_REQUEST, sender='Host', listing='Studio')
        self.assertEqual(Notification.objects.count(), 1)
        self.user.refresh_from_db()
        self.assertEqual(self.user.fcm_token, 'device-token-1')

    def test_unread_notifications_of_a_group_are_merged(self, send):
        notify(self.user, NotificationType.NEW_MESSAGE, group='conversation-1', sender='Host', text='Hello')
        notify(self.user, NotificationType.NEW_MESSAGE, group='conversation-1', sender='Host', text='Are you there?')
        self.assertEqual(Notification.objects.count(), 1)
        self.assertEqual(Notification.objects.get().body, 'Are you there?')
        Notification.objects.update(is_read=True)
        notify(self.user, NotificationType.NEW_MESSAGE, group='conversation-1', sender='Host', text='New one')
        self.assertEqual(Notification.objects.count(), 2)


class NotificationApiTests(TestCase):
    def setUp(self):
        self.user = make_user('student@colohouse.com')
        self.other = make_user('host@colohouse.com')
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
        self.first = notify(self.user, NotificationType.HOUSING_REQUEST, sender='Host', listing='Studio')
        self.second = notify(self.user, NotificationType.REQUEST_ACCEPTED, owner='Host', listing='Studio')
        notify(self.other, NotificationType.HOUSING_REQUEST, sender='Student', listing='Room')

    def test_list_shows_only_my_notifications_newest_first(self):
        response = self.client.get(reverse('notifications:list'))
        self.assertEqual(response.status_code, 200)
        self.assertEqual([item['id'] for item in response.data], [self.second.id, self.first.id])

    def test_unread_filter_and_count(self):
        self.first.mark_as_read()
        response = self.client.get(reverse('notifications:list'), {'unread': 'true'})
        self.assertEqual([item['id'] for item in response.data], [self.second.id])
        self.assertEqual(self.client.get(reverse('notifications:unread_count')).data, {'unread': 1})

    def test_mark_one_as_read(self):
        response = self.client.post(reverse('notifications:mark_read', args=[self.first.id]))
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data['is_read'])

    def test_cannot_mark_someone_elses_notification(self):
        theirs = Notification.objects.get(user=self.other)
        response = self.client.post(reverse('notifications:mark_read', args=[theirs.id]))
        self.assertEqual(response.status_code, 404)

    def test_mark_all_as_read(self):
        response = self.client.post(reverse('notifications:mark_all_read'))
        self.assertEqual(response.data, {'updated': 2})
        self.assertEqual(Notification.objects.filter(user=self.other, is_read=False).count(), 1)

    def test_requires_token(self):
        self.assertEqual(APIClient().get(reverse('notifications:list')).status_code, 401)


class DeviceTests(TestCase):
    def setUp(self):
        self.user = make_user('student@colohouse.com')
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_save_token(self):
        response = self.client.post(reverse('notifications:device'), {'fcm_token': 'device-token-1'}, format='json')
        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertEqual(self.user.fcm_token, 'device-token-1')

    def test_token_moves_to_the_new_account_on_the_same_phone(self):
        previous = make_user('host@colohouse.com', fcm_token='device-token-1')
        self.client.post(reverse('notifications:device'), {'fcm_token': 'device-token-1'}, format='json')
        previous.refresh_from_db()
        self.assertEqual(previous.fcm_token, '')

    def test_delete_token_on_logout(self):
        self.user.fcm_token = 'device-token-1'
        self.user.save()
        response = self.client.delete(reverse('notifications:device'))
        self.assertEqual(response.status_code, 204)
        self.user.refresh_from_db()
        self.assertEqual(self.user.fcm_token, '')

    def test_logout_on_an_old_phone_keeps_the_new_phone(self):
        self.user.fcm_token = 'new-phone'
        self.user.save()
        self.client.delete(reverse('notifications:device'), {'fcm_token': 'old-phone'}, format='json')
        self.user.refresh_from_db()
        self.assertEqual(self.user.fcm_token, 'new-phone')
        self.client.delete(reverse('notifications:device'), {'fcm_token': 'new-phone'}, format='json')
        self.user.refresh_from_db()
        self.assertEqual(self.user.fcm_token, '')

    def test_empty_token_is_rejected(self):
        response = self.client.post(reverse('notifications:device'), {'fcm_token': ''}, format='json')
        self.assertEqual(response.status_code, 400)


class HousingEventTests(TestCase):
    """Sending / accepting / declining a request notifies the other person."""

    def setUp(self):
        self.host = make_user('host@colohouse.com', fcm_token='host-device')
        self.host.first_name = 'Host'
        self.host.save()
        self.student = make_user('student@colohouse.com', fcm_token='student-device')
        self.listing = make_listing(self.host)
        self.host_client = APIClient()
        self.host_client.force_authenticate(user=self.host)
        self.client = APIClient()
        self.client.force_authenticate(user=self.student)

    def send_request(self):
        return self.client.post(reverse('housing:send_request', args=[self.listing.id]), {}, format='json').data['id']

    def test_new_request_notifies_the_host(self):
        request_id = self.send_request()
        notification = Notification.objects.get(user=self.host)
        self.assertEqual(notification.type, NotificationType.HOUSING_REQUEST)
        self.assertEqual(notification.body, 'Student wants to rent "Studio in Tunis".')
        self.assertEqual(notification.data, {'screen': 'received_requests', 'request_id': request_id})

    @patch('housing.views.try_sync_conversation')
    @patch('notifications.services.messaging.send')
    def test_accept_opens_the_chat_and_notifies_the_student(self, send, sync):
        request_id = self.send_request()
        with self.captureOnCommitCallbacks(execute=True):
            response = self.host_client.post(reverse('housing:accept_request', args=[request_id]))
        self.assertEqual(response.status_code, 200)
        conversation = Conversation.objects.get(request_id=request_id)
        self.assertEqual(response.data['conversation_id'], conversation.id)
        sync.assert_called_once_with(conversation)

        notification = Notification.objects.get(user=self.student)
        self.assertEqual(notification.type, NotificationType.REQUEST_ACCEPTED)
        self.assertEqual(notification.data['conversation_id'], conversation.id)
        self.assertEqual(send.call_args.args[0].token, 'student-device')

    def test_decline_notifies_the_student(self):
        request_id = self.send_request()
        self.host_client.post(reverse('housing:decline_request', args=[request_id]))
        notification = Notification.objects.get(user=self.student)
        self.assertEqual(notification.type, NotificationType.REQUEST_DECLINED)
        self.assertFalse(Conversation.objects.exists())

    def test_failed_accept_creates_nothing(self):
        request_id = self.send_request()
        self.listing.status = ListingStatus.PAUSED
        self.listing.save()
        response = self.host_client.post(reverse('housing:accept_request', args=[request_id]))
        self.assertEqual(response.status_code, 400)
        self.assertFalse(Conversation.objects.exists())
        self.assertFalse(Notification.objects.filter(user=self.student).exists())
        self.assertEqual(HousingRequest.objects.get().status, 'pending')

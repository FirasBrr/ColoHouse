import io
import shutil
import tempfile
from unittest.mock import patch

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.urls import reverse
from firebase_admin import auth as firebase_auth
from PIL import Image
from rest_framework.test import APIClient
from .firebase import FirebaseUnavailable
from .models import City, RoommateProfile, User

TEMP_MEDIA = tempfile.mkdtemp()


def make_image(name='avatar.png'):
    file = io.BytesIO()
    Image.new('RGB', (50, 50), 'blue').save(file, 'PNG')
    return SimpleUploadedFile(name, file.getvalue(), content_type='image/png')


class AuthTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.register_data = {
            'email': 'student@colohouse.com',
            'first_name': 'Student',
            'last_name': 'Test',
            'password': 'StrongPass123!',
        }

    def test_register_creates_user(self):
        response = self.client.post(reverse('accounts:register'), self.register_data)
        self.assertEqual(response.status_code, 201)
        self.assertNotIn('password', response.data)
        user = User.objects.get(email='student@colohouse.com')
        self.assertTrue(user.check_password('StrongPass123!'))

    def test_register_duplicate_email_is_rejected(self):
        self.client.post(reverse('accounts:register'), self.register_data)
        data = {**self.register_data, 'email': 'STUDENT@colohouse.com'}
        response = self.client.post(reverse('accounts:register'), data)
        self.assertEqual(response.status_code, 400)

    def test_register_weak_password_is_rejected(self):
        data = {**self.register_data, 'password': '123'}
        response = self.client.post(reverse('accounts:register'), data)
        self.assertEqual(response.status_code, 400)

    def test_login_returns_tokens(self):
        self.client.post(reverse('accounts:register'), self.register_data)
        response = self.client.post(reverse('accounts:login'), {
            'email': 'Student@colohouse.com',
            'password': 'StrongPass123!',
        })
        self.assertEqual(response.status_code, 200)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)

    def test_login_wrong_password(self):
        self.client.post(reverse('accounts:register'), self.register_data)
        response = self.client.post(reverse('accounts:login'), {
            'email': 'student@colohouse.com',
            'password': 'wrong-password',
        })
        self.assertEqual(response.status_code, 401)

    def test_refresh_returns_new_access(self):
        self.client.post(reverse('accounts:register'), self.register_data)
        login = self.client.post(reverse('accounts:login'), {
            'email': 'student@colohouse.com',
            'password': 'StrongPass123!',
        })
        response = self.client.post(reverse('accounts:token_refresh'), {'refresh': login.data['refresh']})
        self.assertEqual(response.status_code, 200)
        self.assertIn('access', response.data)

    def test_me_requires_token(self):
        response = self.client.get(reverse('accounts:me'))
        self.assertEqual(response.status_code, 401)

    def test_me_with_token(self):
        self.client.post(reverse('accounts:register'), self.register_data)
        login = self.client.post(reverse('accounts:login'), {
            'email': 'student@colohouse.com',
            'password': 'StrongPass123!',
        })
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + login.data['access'])
        response = self.client.get(reverse('accounts:me'))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['email'], 'student@colohouse.com')


@override_settings(MEDIA_ROOT=TEMP_MEDIA)
class ProfileTests(TestCase):
    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(TEMP_MEDIA, ignore_errors=True)
        super().tearDownClass()

    def setUp(self):
        self.user = User.objects.create_user(
            'student@colohouse.com', 'StrongPass123!', first_name='Student', last_name='Test'
        )
        self.city = City.objects.create(
            name='Tunis', region='Tunis', latitude=36.8, longitude=10.18
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_get_profile(self):
        response = self.client.get(reverse('accounts:me'))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['first_name'], 'Student')
        self.assertIsNone(response.data['city'])
        self.assertIsNone(response.data['profile_picture'])
        self.assertFalse(response.data['is_verified'])

    def test_profile_requires_token(self):
        response = APIClient().get(reverse('accounts:me'))
        self.assertEqual(response.status_code, 401)

    def test_update_profile(self):
        response = self.client.patch(reverse('accounts:me'), {
            'phone': '+21612345678',
            'bio': 'Calm student, likes cooking.',
            'institution': 'Test University',
            'occupation': 'Computer Science student',
            'city_id': self.city.id,
        }, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['city']['name'], 'Tunis')
        self.user.refresh_from_db()
        self.assertEqual(self.user.phone, '+21612345678')
        self.assertEqual(self.user.institution, 'Test University')
        self.assertEqual(self.user.occupation, 'Computer Science student')
        self.assertEqual(self.user.city, self.city)

    def test_remove_city(self):
        self.user.city = self.city
        self.user.save()
        response = self.client.patch(reverse('accounts:me'), {'city_id': None}, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertIsNone(response.data['city'])

    def test_unknown_city_is_rejected(self):
        response = self.client.patch(reverse('accounts:me'), {'city_id': 999}, format='json')
        self.assertEqual(response.status_code, 400)

    def test_email_cannot_be_changed(self):
        self.client.patch(reverse('accounts:me'), {'email': 'other@colohouse.com'}, format='json')
        self.user.refresh_from_db()
        self.assertEqual(self.user.email, 'student@colohouse.com')

    def test_user_cannot_verify_himself(self):
        self.client.patch(reverse('accounts:me'), {'is_verified': True}, format='json')
        self.user.refresh_from_db()
        self.assertFalse(self.user.is_verified)

    def test_invalid_phone_is_rejected(self):
        response = self.client.patch(reverse('accounts:me'), {'phone': 'abc'}, format='json')
        self.assertEqual(response.status_code, 400)
        self.assertIn('phone', response.data)

    def test_upload_profile_picture(self):
        response = self.client.patch(
            reverse('accounts:me'), {'profile_picture': make_image()}, format='multipart'
        )
        self.assertEqual(response.status_code, 200)
        self.assertIn('/media/profile_pictures/', response.data['profile_picture'])

    def test_upload_non_image_is_rejected(self):
        file = SimpleUploadedFile('notes.txt', b'hello', content_type='text/plain')
        response = self.client.patch(
            reverse('accounts:me'), {'profile_picture': file}, format='multipart'
        )
        self.assertEqual(response.status_code, 400)

    def test_notification_settings(self):
        response = self.client.patch(reverse('accounts:me'), {
            'push_enabled': False,
            'notify_messages': False,
        }, format='json')
        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertFalse(self.user.push_enabled)
        self.assertFalse(self.user.notify_messages)
        self.assertTrue(self.user.notify_requests)

    def test_delete_account(self):
        RoommateProfile.objects.create(user=self.user)
        response = self.client.delete(reverse('accounts:me'))
        self.assertEqual(response.status_code, 204)
        self.assertFalse(User.objects.filter(email='student@colohouse.com').exists())
        self.assertEqual(RoommateProfile.objects.count(), 0)


class PreferencesTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            'student@colohouse.com', 'StrongPass123!', first_name='Student', last_name='Test'
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_get_creates_empty_preferences(self):
        response = self.client.get(reverse('accounts:preferences'))
        self.assertEqual(response.status_code, 200)
        self.assertIsNone(response.data['budget'])
        self.assertFalse(response.data['looking_for_room'])
        self.assertTrue(RoommateProfile.objects.filter(user=self.user).exists())

    def test_update_preferences(self):
        response = self.client.patch(reverse('accounts:preferences'), {
            'budget': 450,
            'preferred_room_type': 'private',
            'move_in_date': '2026-11-01',
            'max_distance_to_center': 3.5,
            'sleep_schedule': 'late',
            'noise_tolerance': 2,
            'cleanliness': 5,
            'smoker': False,
            'accepts_smokers': False,
            'looking_for_room': True,
        }, format='json')
        self.assertEqual(response.status_code, 200)
        profile = RoommateProfile.objects.get(user=self.user)
        self.assertEqual(profile.budget, 450)
        self.assertEqual(profile.max_distance_to_center, 3.5)
        self.assertEqual(profile.sleep_schedule, 'late')
        self.assertEqual(profile.cleanliness, 5)
        self.assertTrue(profile.looking_for_room)

    def test_cleanliness_out_of_range_is_rejected(self):
        response = self.client.patch(reverse('accounts:preferences'), {'cleanliness': 6}, format='json')
        self.assertEqual(response.status_code, 400)

    def test_negative_distance_is_rejected(self):
        response = self.client.patch(
            reverse('accounts:preferences'), {'max_distance_to_center': -1}, format='json'
        )
        self.assertEqual(response.status_code, 400)

    def test_invalid_sleep_schedule_is_rejected(self):
        response = self.client.patch(
            reverse('accounts:preferences'), {'sleep_schedule': 'sometimes'}, format='json'
        )
        self.assertEqual(response.status_code, 400)

    def test_preferences_require_token(self):
        response = APIClient().get(reverse('accounts:preferences'))
        self.assertEqual(response.status_code, 401)


def google_claims(**extra):
    claims = {
        'uid': 'firebase-uid-1',
        'email': 'student@colohouse.com',
        'email_verified': True,
        'name': 'Student Test Account',
        'firebase': {'sign_in_provider': 'google.com'},
    }
    claims.update(extra)
    return claims


@patch('accounts.serializers.verify_id_token')
class FirebaseLoginTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.url = reverse('accounts:firebase_login')

    def login(self, **data):
        return self.client.post(self.url, {'id_token': 'firebase-token', **data}, format='json')

    def test_new_google_user_is_created(self, verify):
        verify.return_value = google_claims()
        response = self.login()
        self.assertEqual(response.status_code, 201)
        self.assertTrue(response.data['created'])
        user = User.objects.get(firebase_uid='firebase-uid-1')
        self.assertEqual(user.email, 'student@colohouse.com')
        self.assertEqual(user.first_name, 'Student')
        self.assertEqual(user.last_name, 'Test Account')
        self.assertFalse(user.has_usable_password())
        verify.assert_called_once_with('firebase-token')

    def test_returned_tokens_work_on_the_api(self, verify):
        verify.return_value = google_claims()
        access = self.login().data['access']
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + access)
        response = self.client.get(reverse('accounts:me'))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['email'], 'student@colohouse.com')

    def test_refresh_token_works(self, verify):
        verify.return_value = google_claims()
        refresh = self.login().data['refresh']
        response = self.client.post(reverse('accounts:token_refresh'), {'refresh': refresh})
        self.assertEqual(response.status_code, 200)

    def test_names_sent_by_the_app_are_used(self, verify):
        verify.return_value = google_claims(name=None, firebase={'sign_in_provider': 'password'})
        response = self.login(first_name='Student', last_name='Test')
        self.assertEqual(response.status_code, 201)
        user = User.objects.get()
        self.assertEqual((user.first_name, user.last_name), ('Student', 'Test'))

    def test_new_account_requires_verified_email(self, verify):
        verify.return_value = google_claims(email_verified=False, firebase={'sign_in_provider': 'password'})
        response = self.login(first_name='Student', last_name='Test')
        self.assertEqual(response.status_code, 400)
        self.assertIn('non_field_errors', response.data)
        self.assertEqual(User.objects.count(), 0)

    def test_returning_user_is_not_duplicated(self, verify):
        verify.return_value = google_claims()
        self.login()
        response = self.login()
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.data['created'])
        self.assertEqual(User.objects.count(), 1)

    def test_returning_user_found_by_uid_even_if_email_changed(self, verify):
        verify.return_value = google_claims()
        self.login()
        verify.return_value = google_claims(email='new@colohouse.com')
        response = self.login()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(User.objects.count(), 1)

    def test_existing_account_is_linked_when_email_verified(self, verify):
        user = User.objects.create_user('student@colohouse.com', 'StrongPass123!', first_name='Student', last_name='Test')
        verify.return_value = google_claims(email='Student@ColoHouse.com')
        response = self.login()
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.data['created'])
        user.refresh_from_db()
        self.assertEqual(user.firebase_uid, 'firebase-uid-1')
        self.assertEqual(User.objects.count(), 1)

    def test_linking_removes_the_old_password(self, verify):
        User.objects.create_user('student@colohouse.com', 'StrongPass123!', first_name='Student', last_name='Test')
        verify.return_value = google_claims()
        self.login()
        user = User.objects.get()
        self.assertFalse(user.has_usable_password())
        response = self.client.post(
            reverse('accounts:login'), {'email': 'student@colohouse.com', 'password': 'StrongPass123!'}
        )
        self.assertEqual(response.status_code, 401)

    def test_linking_revokes_tokens_issued_with_the_old_password(self, verify):
        User.objects.create_user('student@colohouse.com', 'StrongPass123!', first_name='Student', last_name='Test')
        old = self.client.post(
            reverse('accounts:login'), {'email': 'student@colohouse.com', 'password': 'StrongPass123!'}
        ).data
        verify.return_value = google_claims()
        self.login()

        other = APIClient()
        other.credentials(HTTP_AUTHORIZATION='Bearer ' + old['access'])
        self.assertEqual(other.get(reverse('accounts:me')).status_code, 401)
        refreshed = other.post(reverse('accounts:token_refresh'), {'refresh': old['refresh']})
        if refreshed.status_code == 200:
            other.credentials(HTTP_AUTHORIZATION='Bearer ' + refreshed.data['access'])
            self.assertEqual(other.get(reverse('accounts:me')).status_code, 401)

    def test_existing_account_not_linked_when_email_not_verified(self, verify):
        user = User.objects.create_user('student@colohouse.com', 'StrongPass123!', first_name='Student', last_name='Test')
        verify.return_value = google_claims(email_verified=False)
        response = self.login()
        self.assertEqual(response.status_code, 400)
        self.assertIn('non_field_errors', response.data)
        user.refresh_from_db()
        self.assertIsNone(user.firebase_uid)

    def test_email_linked_to_another_firebase_account_is_rejected(self, verify):
        User.objects.create_user('student@colohouse.com', 'StrongPass123!', firebase_uid='other-uid')
        verify.return_value = google_claims()
        response = self.login()
        self.assertEqual(response.status_code, 400)

    def test_invalid_token_is_rejected(self, verify):
        verify.side_effect = firebase_auth.InvalidIdTokenError('bad token')
        response = self.login()
        self.assertEqual(response.status_code, 401)
        self.assertEqual(User.objects.count(), 0)

    def test_expired_token_is_rejected(self, verify):
        verify.side_effect = firebase_auth.ExpiredIdTokenError('expired', cause=None)
        self.assertEqual(self.login().status_code, 401)

    def test_disabled_user_is_rejected(self, verify):
        User.objects.create_user('student@colohouse.com', 'StrongPass123!', firebase_uid='firebase-uid-1', is_active=False)
        verify.return_value = google_claims()
        self.assertEqual(self.login().status_code, 401)

    def test_account_without_email_is_rejected(self, verify):
        verify.return_value = google_claims(email=None)
        self.assertEqual(self.login().status_code, 400)

    def test_missing_token_is_rejected(self, verify):
        response = self.client.post(self.url, {}, format='json')
        self.assertEqual(response.status_code, 400)
        self.assertIn('id_token', response.data)
        verify.assert_not_called()

    def test_firebase_not_configured(self, verify):
        verify.side_effect = FirebaseUnavailable()
        self.assertEqual(self.login().status_code, 503)

    def test_old_authorization_header_is_ignored(self, verify):
        verify.return_value = google_claims()
        self.client.credentials(HTTP_AUTHORIZATION='Bearer expired-or-garbage')
        self.assertEqual(self.login().status_code, 201)

    def test_firebase_user_cannot_use_password_login(self, verify):
        verify.return_value = google_claims()
        self.login()
        response = self.client.post(
            reverse('accounts:login'), {'email': 'student@colohouse.com', 'password': 'StrongPass123!'}
        )
        self.assertEqual(response.status_code, 401)

    def test_firebase_uid_not_editable_from_profile(self, verify):
        verify.return_value = google_claims()
        access = self.login().data['access']
        self.client.credentials(HTTP_AUTHORIZATION='Bearer ' + access)
        self.client.patch(reverse('accounts:me'), {'firebase_uid': 'hijack'}, format='json')
        self.assertTrue(User.objects.filter(firebase_uid='firebase-uid-1').exists())
        self.assertNotIn('firebase_uid', self.client.get(reverse('accounts:me')).data)


class FirebaseConfigTests(TestCase):
    def post(self):
        return APIClient().post(reverse('accounts:firebase_login'), {'id_token': 'x'}, format='json')

    def test_missing_key_file_gives_503(self):
        from firebase_admin import _apps
        with patch.dict(_apps, clear=True), self.settings(FIREBASE_KEY_PATH='does-not-exist.json'):
            response = self.post()
        self.assertEqual(response.status_code, 503)

    def test_wrong_key_file_gives_503(self):
        from firebase_admin import _apps
        with tempfile.NamedTemporaryFile('w', suffix='.json', delete=False) as file:
            file.write('{"project_info": {"project_id": "colohouse"}, "client": []}')
        try:
            with patch.dict(_apps, clear=True), self.settings(FIREBASE_KEY_PATH=file.name):
                response = self.post()
        finally:
            import os
            os.remove(file.name)
        self.assertEqual(response.status_code, 503)

    @patch('accounts.firebase.get_firebase_app')
    @patch('accounts.firebase.auth.verify_id_token', side_effect=ValueError('no project id'))
    def test_server_config_error_gives_503_not_401(self, verify, get_app):
        self.assertEqual(self.post().status_code, 503)

    @patch('accounts.firebase.get_firebase_app')
    @patch('accounts.firebase.auth.verify_id_token', side_effect=firebase_auth.InvalidIdTokenError('garbage'))
    def test_garbage_token_gives_401(self, verify, get_app):
        self.assertEqual(self.post().status_code, 401)


class CityTests(TestCase):
    def test_city_list_is_public(self):
        City.objects.create(name='Tunis', region='Tunis', latitude=36.8, longitude=10.18)
        response = APIClient().get(reverse('accounts:cities'))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['name'], 'Tunis')

import io
import shutil
import tempfile

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.urls import reverse
from PIL import Image
from rest_framework.test import APIClient

from accounts.models import City, User
from .models import HousingListing, HousingRequest, ListingPhoto, ListingStatus, RequestStatus

TEMP_MEDIA = tempfile.mkdtemp()


def make_image(name='room.png'):
    file = io.BytesIO()
    Image.new('RGB', (50, 50), 'green').save(file, 'PNG')
    return SimpleUploadedFile(name, file.getvalue(), content_type='image/png')


def make_user(email):
    return User.objects.create_user(
        email, 'StrongPass123!', first_name='Student', last_name='Test', phone='+21612345678'
    )


def make_listing(owner, **fields):
    data = {
        'title': 'Room near the center',
        'description': 'Bright private room in a shared flat.',
        'rent': 400,
        'room_type': 'private',
        'address': '12 Main street',
        'latitude': 36.8065,
        'longitude': 10.1815,
        'available_from': '2026-12-01',
    }
    data.update(fields)
    return HousingListing.objects.create(owner=owner, **data)


class HousingTestCase(TestCase):
    def setUp(self):
        self.host = make_user('host@colohouse.com')
        self.student = make_user('student@colohouse.com')
        self.city = City.objects.create(name='Tunis', region='Tunis', latitude=36.8065, longitude=10.1815)
        self.host_client = APIClient()
        self.host_client.force_authenticate(user=self.host)
        self.client = APIClient()
        self.client.force_authenticate(user=self.student)


class ListingTests(HousingTestCase):
    def listing_data(self, **fields):
        data = {
            'title': 'Studio in Tunis',
            'description': 'Quiet studio, 10 min from the center.',
            'rent': 550,
            'deposit': 550,
            'room_type': 'studio',
            'city_id': self.city.id,
            'address': '5 Liberty avenue',
            'latitude': 36.81,
            'longitude': 10.18,
            'available_from': '2026-12-01',
            'rules': 'No parties.',
        }
        data.update(fields)
        return data

    def test_create_listing(self):
        response = self.host_client.post(reverse('housing:listings'), self.listing_data(), format='json')
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['status'], 'active')
        self.assertEqual(response.data['city']['name'], 'Tunis')
        self.assertEqual(response.data['address'], '5 Liberty avenue')
        self.assertEqual(HousingListing.objects.get().owner, self.host)

    def test_create_requires_token(self):
        response = APIClient().post(reverse('housing:listings'), self.listing_data(), format='json')
        self.assertEqual(response.status_code, 401)

    def test_create_draft(self):
        response = self.host_client.post(
            reverse('housing:listings'), self.listing_data(status='draft'), format='json'
        )
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['status'], 'draft')

    def test_create_hidden_is_rejected(self):
        response = self.host_client.post(
            reverse('housing:listings'), self.listing_data(status='hidden'), format='json'
        )
        self.assertEqual(response.status_code, 400)

    def test_invalid_rent_and_latitude_are_rejected(self):
        response = self.host_client.post(
            reverse('housing:listings'), self.listing_data(rent=0, latitude=120), format='json'
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn('rent', response.data)
        self.assertIn('latitude', response.data)

    def test_address_and_phone_hidden_from_others(self):
        listing = make_listing(self.host)
        response = self.client.get(reverse('housing:listing_detail', args=[listing.id]))
        self.assertEqual(response.status_code, 200)
        self.assertIsNone(response.data['address'])
        self.assertIsNone(response.data['owner_phone'])
        self.assertFalse(response.data['contact_visible'])
        self.assertEqual(response.data['latitude'], 36.81)
        self.assertNotIn('email', response.data['owner'])

    def test_owner_sees_address_and_phone(self):
        listing = make_listing(self.host)
        response = self.host_client.get(reverse('housing:listing_detail', args=[listing.id]))
        self.assertEqual(response.data['address'], '12 Main street')
        self.assertEqual(response.data['owner_phone'], '+21612345678')
        self.assertEqual(response.data['latitude'], 36.8065)

    def test_owner_can_edit(self):
        listing = make_listing(self.host)
        response = self.host_client.patch(
            reverse('housing:listing_detail', args=[listing.id]), {'rent': 450}, format='json'
        )
        self.assertEqual(response.status_code, 200)
        listing.refresh_from_db()
        self.assertEqual(listing.rent, 450)

    def test_other_user_cannot_edit(self):
        listing = make_listing(self.host)
        response = self.client.patch(
            reverse('housing:listing_detail', args=[listing.id]), {'rent': 1}, format='json'
        )
        self.assertEqual(response.status_code, 403)

    def test_pause_then_reactivate(self):
        listing = make_listing(self.host)
        url = reverse('housing:listing_detail', args=[listing.id])
        response = self.host_client.patch(url, {'status': 'paused'}, format='json')
        self.assertEqual(response.data['status'], 'paused')
        response = self.host_client.patch(url, {'status': 'active'}, format='json')
        self.assertEqual(response.data['status'], 'active')

    def test_closed_listing_cannot_be_reopened(self):
        listing = make_listing(self.host, status=ListingStatus.CLOSED)
        response = self.host_client.patch(
            reverse('housing:listing_detail', args=[listing.id]), {'status': 'active'}, format='json'
        )
        self.assertEqual(response.status_code, 400)

    def test_owner_cannot_unhide_listing(self):
        listing = make_listing(self.host, status=ListingStatus.HIDDEN)
        response = self.host_client.patch(
            reverse('housing:listing_detail', args=[listing.id]), {'status': 'active'}, format='json'
        )
        self.assertEqual(response.status_code, 400)

    def test_paused_listing_not_visible_to_others(self):
        listing = make_listing(self.host, status=ListingStatus.PAUSED)
        response = self.client.get(reverse('housing:listing_detail', args=[listing.id]))
        self.assertEqual(response.status_code, 404)

    def test_my_listings_shows_all_statuses(self):
        make_listing(self.host)
        make_listing(self.host, status=ListingStatus.PAUSED)
        make_listing(self.student)
        response = self.host_client.get(reverse('housing:my_listings'))
        self.assertEqual(len(response.data), 2)


class SearchTests(HousingTestCase):
    def setUp(self):
        super().setUp()
        self.cheap = make_listing(self.host, title='Cheap shared room', rent=250, room_type='shared', city=self.city)
        self.studio = make_listing(self.host, title='Nice studio', rent=600, room_type='studio', city=self.city,
                                   latitude=36.83, longitude=10.20)
        self.far = make_listing(self.host, title='Room in Sousse', rent=300, latitude=35.8256, longitude=10.6360)
        make_listing(self.host, title='Paused room', status=ListingStatus.PAUSED)

    def search(self, **params):
        response = self.client.get(reverse('housing:listings'), params)
        self.assertEqual(response.status_code, 200, response.data)
        return [item['title'] for item in response.data]

    def test_only_active_listings(self):
        titles = self.search()
        self.assertEqual(len(titles), 3)
        self.assertNotIn('Paused room', titles)

    def test_filter_by_rent(self):
        self.assertEqual(self.search(min_rent=280, max_rent=500), ['Room in Sousse'])

    def test_filter_by_room_type(self):
        self.assertEqual(self.search(room_type='studio'), ['Nice studio'])

    def test_filter_by_city(self):
        self.assertCountEqual(self.search(city=self.city.id), ['Cheap shared room', 'Nice studio'])

    def test_text_search(self):
        self.assertEqual(self.search(q='sousse'), ['Room in Sousse'])

    def test_available_by(self):
        make_listing(self.host, title='Later room', available_from='2027-06-01')
        self.assertNotIn('Later room', self.search(available_by='2027-01-01'))

    def test_radius_search_with_distance(self):
        response = self.client.get(reverse('housing:listings'), {
            'lat': 36.8065, 'lng': 10.1815, 'radius_km': 10, 'ordering': 'distance',
        })
        self.assertEqual(response.status_code, 200)
        titles = [item['title'] for item in response.data]
        self.assertEqual(titles, ['Cheap shared room', 'Nice studio'])
        self.assertEqual(response.data[0]['distance_km'], 0)
        self.assertGreater(response.data[1]['distance_km'], 2)

    def test_radius_from_city_center(self):
        titles = self.search(city=self.city.id, radius_km=1)
        self.assertEqual(titles, ['Cheap shared room'])

    def test_order_by_rent(self):
        self.assertEqual(self.search(ordering='rent')[0], 'Cheap shared room')

    def test_distance_without_center_is_rejected(self):
        response = self.client.get(reverse('housing:listings'), {'radius_km': 5})
        self.assertEqual(response.status_code, 400)

    def test_bad_params_are_rejected(self):
        response = self.client.get(reverse('housing:listings'), {'lat': 'abc', 'room_type': 'castle'})
        self.assertEqual(response.status_code, 400)
        self.assertIn('lat', response.data)
        self.assertIn('room_type', response.data)


@override_settings(MEDIA_ROOT=TEMP_MEDIA)
class PhotoTests(HousingTestCase):
    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(TEMP_MEDIA, ignore_errors=True)
        super().tearDownClass()

    def setUp(self):
        super().setUp()
        self.listing = make_listing(self.host)
        self.url = reverse('housing:listing_photos', args=[self.listing.id])

    def test_owner_uploads_photo(self):
        response = self.host_client.post(self.url, {'image': make_image()}, format='multipart')
        self.assertEqual(response.status_code, 201)
        self.assertIn('/media/listing_photos/', response.data['image'])
        detail = self.client.get(reverse('housing:listing_detail', args=[self.listing.id]))
        self.assertEqual(len(detail.data['photos']), 1)

    def test_other_user_cannot_upload(self):
        response = self.client.post(self.url, {'image': make_image()}, format='multipart')
        self.assertEqual(response.status_code, 404)

    def test_non_image_is_rejected(self):
        file = SimpleUploadedFile('notes.txt', b'hello', content_type='text/plain')
        response = self.host_client.post(self.url, {'image': file}, format='multipart')
        self.assertEqual(response.status_code, 400)

    def test_owner_deletes_photo(self):
        photo = ListingPhoto.objects.create(listing=self.listing, image=make_image())
        response = self.host_client.delete(
            reverse('housing:listing_photo_delete', args=[self.listing.id, photo.id])
        )
        self.assertEqual(response.status_code, 204)
        self.assertEqual(ListingPhoto.objects.count(), 0)


class RequestTests(HousingTestCase):
    def setUp(self):
        super().setUp()
        self.listing = make_listing(self.host)

    def send(self, message='Hello, is the room still free?'):
        return self.client.post(
            reverse('housing:send_request', args=[self.listing.id]), {'message': message}, format='json'
        )

    def test_send_request(self):
        response = self.send()
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['status'], 'pending')
        self.assertIsNone(response.data['contact'])
        self.assertEqual(HousingRequest.objects.get().sender, self.student)

    def test_cannot_request_own_listing(self):
        response = self.host_client.post(reverse('housing:send_request', args=[self.listing.id]), {}, format='json')
        self.assertEqual(response.status_code, 400)

    def test_cannot_send_twice(self):
        self.send()
        response = self.send()
        self.assertEqual(response.status_code, 400)

    def test_cannot_request_paused_listing(self):
        self.listing.status = ListingStatus.PAUSED
        self.listing.save()
        self.assertEqual(self.send().status_code, 404)

    def test_host_sees_received_requests(self):
        self.send()
        response = self.host_client.get(reverse('housing:received_requests'), {'status': 'pending'})
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['sender']['first_name'], 'Student')
        self.assertNotIn('phone', response.data[0]['sender'])

    def test_student_sees_sent_requests(self):
        self.send()
        response = self.client.get(reverse('housing:sent_requests'))
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['listing']['title'], 'Room near the center')

    def test_accept_reveals_contact(self):
        request_id = self.send().data['id']
        response = self.host_client.post(reverse('housing:accept_request', args=[request_id]))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'accepted')
        self.assertEqual(response.data['contact']['address'], '12 Main street')
        self.assertEqual(response.data['contact']['sender_phone'], '+21612345678')

        detail = self.client.get(reverse('housing:listing_detail', args=[self.listing.id]))
        self.assertTrue(detail.data['contact_visible'])
        self.assertEqual(detail.data['address'], '12 Main street')
        self.assertEqual(detail.data['owner_phone'], '+21612345678')
        self.assertEqual(detail.data['my_request']['status'], 'accepted')

    def test_decline(self):
        request_id = self.send().data['id']
        response = self.host_client.post(reverse('housing:decline_request', args=[request_id]))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(HousingRequest.objects.get().status, RequestStatus.DECLINED)

    def test_cannot_accept_declined_request(self):
        request_id = self.send().data['id']
        self.host_client.post(reverse('housing:decline_request', args=[request_id]))
        response = self.host_client.post(reverse('housing:accept_request', args=[request_id]))
        self.assertEqual(response.status_code, 400)

    def test_sender_cannot_accept_own_request(self):
        request_id = self.send().data['id']
        response = self.client.post(reverse('housing:accept_request', args=[request_id]))
        self.assertEqual(response.status_code, 404)

    def test_cannot_accept_on_paused_listing(self):
        request_id = self.send().data['id']
        self.listing.status = ListingStatus.PAUSED
        self.listing.save()
        response = self.host_client.post(reverse('housing:accept_request', args=[request_id]))
        self.assertEqual(response.status_code, 400)
        self.assertEqual(HousingRequest.objects.get().status, RequestStatus.PENDING)

    def test_sender_cancels(self):
        request_id = self.send().data['id']
        response = self.client.post(reverse('housing:cancel_request', args=[request_id]))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'cancelled')

    def test_can_send_again_after_cancel(self):
        request_id = self.send().data['id']
        self.client.post(reverse('housing:cancel_request', args=[request_id]))
        self.assertEqual(self.send().status_code, 201)

    def test_host_cannot_cancel_student_request(self):
        request_id = self.send().data['id']
        response = self.host_client.post(reverse('housing:cancel_request', args=[request_id]))
        self.assertEqual(response.status_code, 404)

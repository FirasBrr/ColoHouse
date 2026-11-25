from datetime import date

from django.db import connection
from django.test import SimpleTestCase, TestCase
from django.test.utils import CaptureQueriesContext
from django.urls import reverse
from rest_framework.test import APIClient

from accounts.models import City, RoommateProfile, User
from housing.models import HousingListing, HousingRequest
from .engine import WEIGHTS, candidates_queryset, compute_match, explain, incompatibilities
from .models import MatchResult

TUNIS = dict(name='Tunis', latitude=36.8065, longitude=10.1815)
ARIANA = dict(name='Ariana', latitude=36.8665, longitude=10.1647)
SOUSSE = dict(name='Sousse', latitude=35.8256, longitude=10.6360)

SAME = dict(budget=500, sleep_schedule='normal', cleanliness=4, noise_tolerance=3, smoker=False, accepts_smokers=True)


def profile(city=None, **prefs):
    """Unsaved profile, enough for the score functions (no database)."""
    user = User(email='x@colohouse.com', city=City(**city) if city else None)
    return RoommateProfile(user=user, looking_for_room=True, **prefs)


class ScoreTests(SimpleTestCase):
    def test_identical_profiles_score_100(self):
        match = compute_match(profile(TUNIS, **SAME), profile(TUNIS, **SAME))
        self.assertEqual(match['score'], 100)
        self.assertEqual(set(match['breakdown']), set(WEIGHTS))
        self.assertEqual(sum(WEIGHTS.values()), 100)

    def test_missing_values_count_as_half(self):
        match = compute_match(profile(), profile())
        # budget 12.5 + sleep 10 + cleanliness 10 + noise 7.5 + smoking 10 (both non smokers) + distance 5
        self.assertEqual(match['score'], 55)
        self.assertFalse(match['breakdown']['budget']['known'])
        self.assertTrue(match['breakdown']['smoking']['known'])

    def test_budget_points(self):
        match = compute_match(profile(budget=400), profile(budget=500))
        # 20 % apart out of the 30 % tolerance -> 1/3 of 25 points
        self.assertEqual(match['breakdown']['budget']['points'], 8.3)
        self.assertEqual(match['breakdown']['budget']['you'], 400)
        self.assertEqual(match['breakdown']['budget']['them'], 500)

    def test_sleep_schedule_points(self):
        same = compute_match(profile(sleep_schedule='late'), profile(sleep_schedule='late'))
        close = compute_match(profile(sleep_schedule='late'), profile(sleep_schedule='normal'))
        opposite = compute_match(profile(sleep_schedule='late'), profile(sleep_schedule='early'))
        self.assertEqual(same['breakdown']['sleep_schedule']['points'], 20)
        self.assertEqual(close['breakdown']['sleep_schedule']['points'], 10)
        self.assertEqual(opposite['breakdown']['sleep_schedule']['points'], 0)

    def test_cleanliness_and_noise_scale(self):
        match = compute_match(profile(cleanliness=5, noise_tolerance=1), profile(cleanliness=1, noise_tolerance=2))
        self.assertEqual(match['breakdown']['cleanliness']['points'], 0)
        self.assertEqual(match['breakdown']['noise_tolerance']['points'], 11.2)

    def test_smoker_with_non_smoker_gets_half(self):
        match = compute_match(profile(smoker=True), profile(smoker=False, accepts_smokers=True))
        self.assertEqual(match['breakdown']['smoking']['points'], 5)

    def test_distance_between_cities(self):
        near = compute_match(profile(TUNIS, max_distance_to_center=10), profile(ARIANA))
        far = compute_match(profile(TUNIS, max_distance_to_center=10), profile(SOUSSE))
        self.assertAlmostEqual(near['breakdown']['distance']['km'], 6.9, delta=0.3)
        self.assertGreater(near['breakdown']['distance']['points'], 6)
        self.assertEqual(far['breakdown']['distance']['points'], 0)

    def test_explanation_in_three_languages(self):
        breakdown = compute_match(profile(TUNIS, **SAME), profile(TUNIS, **SAME))['breakdown']
        self.assertEqual(explain(breakdown, 'en'), 'Good match on budget, sleep schedule, cleanliness.')
        self.assertEqual(explain(breakdown, 'fr'), 'Bonne compatibilité : budget, rythme de sommeil, propreté.')
        self.assertEqual(explain(breakdown, 'ar'), 'توافق جيد في: الميزانية، مواعيد النوم، النظافة.')

    def test_explanation_mentions_differences(self):
        breakdown = compute_match(profile(sleep_schedule='early', budget=500), profile(sleep_schedule='late', budget=500))['breakdown']
        self.assertEqual(explain(breakdown, 'en'), 'Good match on budget, smoking. Different on sleep schedule.')

    def test_explanation_when_nothing_in_common(self):
        me = profile(smoker=True, cleanliness=1)
        other = profile(smoker=False, accepts_smokers=True, cleanliness=5)
        breakdown = compute_match(me, other)['breakdown']
        self.assertEqual(explain(breakdown, 'en'), 'Few things in common. Different on cleanliness.')


class HardFilterTests(SimpleTestCase):
    def test_smoking_both_ways(self):
        self.assertEqual(incompatibilities(profile(smoker=True), profile(accepts_smokers=False)), ['smoking'])
        self.assertEqual(incompatibilities(profile(accepts_smokers=False), profile(smoker=True)), ['smoking'])
        self.assertEqual(incompatibilities(profile(smoker=True), profile(accepts_smokers=True)), [])

    def test_budget_tolerance(self):
        self.assertEqual(incompatibilities(profile(budget=500), profile(budget=350)), [])
        self.assertEqual(incompatibilities(profile(budget=500), profile(budget=349)), ['budget'])
        self.assertEqual(incompatibilities(profile(budget=500), profile(budget=None)), [])

    def test_move_in_dates(self):
        me = profile(move_in_date=date(2026, 12, 1))
        self.assertEqual(incompatibilities(me, profile(move_in_date=date(2027, 1, 30))), [])
        self.assertEqual(incompatibilities(me, profile(move_in_date=date(2027, 3, 1))), ['move_in_date'])

    def test_not_looking(self):
        other = profile()
        other.looking_for_room = False
        self.assertEqual(incompatibilities(profile(), other), ['not_looking'])


def make_profile(email, city=None, looking=True, active=True, **prefs):
    user = User.objects.create_user(
        email, 'StrongPass123!', first_name=email.split('@')[0].title(), last_name='Test',
        city=city, is_active=active,
    )
    return RoommateProfile.objects.create(user=user, looking_for_room=looking, **prefs)


class CandidatesQuerysetTests(TestCase):
    def test_database_filters_match_the_python_rules(self):
        me = make_profile('student@colohouse.com', budget=500, accepts_smokers=False, move_in_date=date(2026, 12, 1))
        others = [
            make_profile('a@colohouse.com', budget=350),
            make_profile('b@colohouse.com', budget=349),
            make_profile('c@colohouse.com', budget=714),
            make_profile('d@colohouse.com', budget=715),
            make_profile('e@colohouse.com', budget=None),
            make_profile('f@colohouse.com', smoker=True),
            make_profile('g@colohouse.com', move_in_date=date(2027, 1, 30)),
            make_profile('h@colohouse.com', move_in_date=date(2027, 2, 1)),
            make_profile('i@colohouse.com', looking=False),
        ]
        found = set(candidates_queryset(me))
        for other in others:
            with self.subTest(other=other.user.email):
                self.assertEqual(other in found, not incompatibilities(me, other))

    def test_excludes_me_and_inactive_users(self):
        me = make_profile('student@colohouse.com')
        inactive = make_profile('old@colohouse.com', active=False)
        found = set(candidates_queryset(me))
        self.assertNotIn(me, found)
        self.assertNotIn(inactive, found)

    def test_smoker_only_sees_people_who_accept_smokers(self):
        me = make_profile('student@colohouse.com', smoker=True)
        ok = make_profile('ok@colohouse.com', accepts_smokers=True)
        no = make_profile('no@colohouse.com', accepts_smokers=False)
        found = set(candidates_queryset(me))
        self.assertIn(ok, found)
        self.assertNotIn(no, found)


class MatchApiTests(TestCase):
    def setUp(self):
        self.tunis = City.objects.create(**TUNIS)
        self.me = make_profile('student@colohouse.com', city=self.tunis, **SAME)
        self.client = APIClient()
        self.client.force_authenticate(user=self.me.user)
        self.best = make_profile('best@colohouse.com', city=self.tunis, **SAME)
        self.medium = make_profile('medium@colohouse.com', city=self.tunis, **{**SAME, 'sleep_schedule': 'late', 'cleanliness': 2})
        self.smoker = make_profile('smoker@colohouse.com', city=self.tunis, **{**SAME, 'smoker': True})
        self.me.accepts_smokers = False
        self.me.save()

    def test_requires_token(self):
        self.assertEqual(APIClient().get(reverse('matching:matches')).status_code, 401)

    def test_ranked_list(self):
        response = self.client.get(reverse('matching:matches'))
        self.assertEqual(response.status_code, 200)
        names = [item['user']['first_name'] for item in response.data]
        self.assertEqual(names, ['Best', 'Medium'])
        best = response.data[0]
        self.assertEqual(best['score'], 100)
        self.assertEqual(best['city'], 'Tunis')
        self.assertEqual(set(best['breakdown']), set(WEIGHTS))
        self.assertTrue(best['explanation'])
        self.assertNotIn('email', best['user'])
        self.assertNotIn('phone', best['user'])

    def test_results_are_saved_and_stale_ones_removed(self):
        self.client.get(reverse('matching:matches'))
        self.assertEqual(MatchResult.objects.filter(requester=self.me).count(), 2)
        self.medium.looking_for_room = False
        self.medium.save()
        self.client.get(reverse('matching:matches'))
        self.assertEqual(list(MatchResult.objects.values_list('candidate', flat=True)), [self.best.id])

    def test_limit_and_min_score(self):
        response = self.client.get(reverse('matching:matches'), {'limit': 1})
        self.assertEqual(len(response.data), 1)
        response = self.client.get(reverse('matching:matches'), {'min_score': 100})
        self.assertEqual([item['user']['first_name'] for item in response.data], ['Best'])

    def test_explanation_in_my_language(self):
        self.me.user.language = 'fr'
        self.me.user.save()
        response = self.client.get(reverse('matching:matches'))
        self.assertTrue(response.data[0]['explanation'].startswith('Bonne compatibilité'))

    def test_detail_says_why_not_compatible(self):
        response = self.client.get(reverse('matching:match_detail', args=[self.smoker.user_id]))
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.data['compatible'])
        self.assertEqual(response.data['reasons'], ['smoking'])
        self.assertIn('score', response.data)

    def test_detail_of_a_compatible_person(self):
        response = self.client.get(reverse('matching:match_detail', args=[self.best.user_id]))
        self.assertTrue(response.data['compatible'])
        self.assertEqual(response.data['score'], 100)

    def test_detail_hidden_for_people_who_did_not_opt_in(self):
        private = make_profile('private@colohouse.com', looking=False, budget=900, smoker=True)
        response = self.client.get(reverse('matching:match_detail', args=[private.user_id]))
        self.assertEqual(response.status_code, 404)
        self.assertNotIn('breakdown', response.data)

    def test_detail_allowed_for_someone_who_sent_me_a_request(self):
        sender = User.objects.create_user('sender@colohouse.com', 'StrongPass123!', first_name='Sender')
        listing = HousingListing.objects.create(
            owner=self.me.user, title='Room', description='Room.', rent=400, room_type='private',
            address='1 Main street', latitude=36.8, longitude=10.18, available_from='2026-12-01',
        )
        HousingRequest.objects.create(listing=listing, sender=sender)
        response = self.client.get(reverse('matching:match_detail', args=[sender.id]))
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data['compatible'])
        self.assertEqual(response.data['reasons'], [])
        self.assertFalse(response.data['breakdown']['budget']['known'])
        self.assertIn('computed_at', response.data)
        self.assertFalse(RoommateProfile.objects.filter(user=sender).exists())

    def test_detail_allowed_for_the_owner_of_a_listing_i_requested(self):
        owner = make_profile('owner@colohouse.com', looking=False)
        listing = HousingListing.objects.create(
            owner=owner.user, title='Room', description='Room.', rent=400, room_type='private',
            address='1 Main street', latitude=36.8, longitude=10.18, available_from='2026-12-01',
        )
        HousingRequest.objects.create(listing=listing, sender=self.me.user)
        response = self.client.get(reverse('matching:match_detail', args=[owner.user_id]))
        self.assertEqual(response.status_code, 200)
        self.assertNotIn('not_looking', response.data['reasons'])

    def test_detail_of_myself_or_unknown_is_404(self):
        self.assertEqual(self.client.get(reverse('matching:match_detail', args=[self.me.user_id])).status_code, 404)
        self.assertEqual(self.client.get(reverse('matching:match_detail', args=[99999])).status_code, 404)

    def test_works_before_preferences_are_filled(self):
        newcomer = User.objects.create_user('new@colohouse.com', 'StrongPass123!')
        client = APIClient()
        client.force_authenticate(user=newcomer)
        response = client.get(reverse('matching:matches'))
        self.assertEqual(response.status_code, 200)

    def test_query_count_does_not_grow_with_candidates(self):
        def count():
            with CaptureQueriesContext(connection) as queries:
                self.client.get(reverse('matching:matches'))
            return len(queries)

        before = count()
        for index in range(10):
            make_profile(f'extra{index}@colohouse.com', city=self.tunis, **SAME)
        self.assertEqual(count(), before)

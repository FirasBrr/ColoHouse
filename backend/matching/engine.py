"""Roommate matching: hard filters first, then a weighted score from 0 to 100 with a breakdown.

The AI (Sprint 4) will only rewrite the explanation; it never computes the score.
"""
import math
from datetime import timedelta

from django.db.models import Q

from accounts.models import RoommateProfile

# Points per criterion (total 100)
WEIGHTS = {
    'budget': 25,
    'sleep_schedule': 20,
    'cleanliness': 20,
    'noise_tolerance': 15,
    'smoking': 10,
    'distance': 10,
}
BUDGET_TOLERANCE = 0.30        # budgets more than 30 % apart are not compatible
MOVE_IN_WINDOW_DAYS = 60       # move-in dates more than 60 days apart are not compatible
DEFAULT_DISTANCE_KM = 10       # used when the requester did not set a max distance
SLEEP_ORDER = {'early': 0, 'normal': 1, 'late': 2}
STRONG = 0.75                  # a criterion at 75 %+ of its points is a strength
WEAK = 0.40                    # a criterion at 40 % or less is a difference


# ---------------- Hard filters ----------------

def candidates_queryset(me):
    """People who can be a roommate for `me` (the hard filters, done by the database)."""
    queryset = RoommateProfile.objects.filter(
        looking_for_room=True, user__is_active=True
    ).exclude(user_id=me.user_id).select_related('user__city')

    # Smoking must be fine in both directions
    if me.smoker:
        queryset = queryset.filter(accepts_smokers=True)
    if not me.accepts_smokers:
        queryset = queryset.filter(smoker=False)
    # |a - b| <= 30 % of the biggest budget  <=>  0.7 * a <= b <= a / 0.7
    if me.budget:
        queryset = queryset.filter(
            Q(budget__isnull=True)
            | Q(budget__gte=me.budget * (1 - BUDGET_TOLERANCE), budget__lte=me.budget / (1 - BUDGET_TOLERANCE))
        )
    if me.move_in_date:
        window = timedelta(days=MOVE_IN_WINDOW_DAYS)
        queryset = queryset.filter(
            Q(move_in_date__isnull=True)
            | Q(move_in_date__range=(me.move_in_date - window, me.move_in_date + window))
        )
    return queryset


def incompatibilities(me, other):
    """Same rules as candidates_queryset, for one person: the list of failed hard filters."""
    reasons = []
    if not other.looking_for_room:
        reasons.append('not_looking')
    if (me.smoker and not other.accepts_smokers) or (other.smoker and not me.accepts_smokers):
        reasons.append('smoking')
    if me.budget and other.budget and abs(me.budget - other.budget) > BUDGET_TOLERANCE * max(me.budget, other.budget):
        reasons.append('budget')
    if me.move_in_date and other.move_in_date and abs((me.move_in_date - other.move_in_date).days) > MOVE_IN_WINDOW_DAYS:
        reasons.append('move_in_date')
    return reasons


# ---------------- Score ----------------

def distance_km(city_a, city_b):
    """Distance between two cities (Haversine formula)."""
    lat1, lng1, lat2, lng2 = map(math.radians, (city_a.latitude, city_a.longitude, city_b.latitude, city_b.longitude))
    a = math.sin((lat2 - lat1) / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin((lng2 - lng1) / 2) ** 2
    return 2 * 6371 * math.asin(math.sqrt(a))


def _scale_1_to_5(a, b):
    """1 when equal, 0 when one says 1 and the other 5."""
    return 1 - abs(a - b) / 4


def criteria(me, other):
    """Each criterion -> (ratio between 0 and 1 or None when a value is missing, details shown in the app)."""
    result = {}

    if me.budget and other.budget:
        gap = abs(me.budget - other.budget) / max(me.budget, other.budget)
        result['budget'] = (max(0.0, 1 - gap / BUDGET_TOLERANCE), {'you': me.budget, 'them': other.budget})
    else:
        result['budget'] = (None, {'you': me.budget, 'them': other.budget})

    if me.sleep_schedule and other.sleep_schedule:
        steps = abs(SLEEP_ORDER[me.sleep_schedule] - SLEEP_ORDER[other.sleep_schedule])
        result['sleep_schedule'] = ([1.0, 0.5, 0.0][steps], {'you': me.sleep_schedule, 'them': other.sleep_schedule})
    else:
        result['sleep_schedule'] = (None, {'you': me.sleep_schedule or None, 'them': other.sleep_schedule or None})

    for name in ('cleanliness', 'noise_tolerance'):
        mine, theirs = getattr(me, name), getattr(other, name)
        ratio = _scale_1_to_5(mine, theirs) if mine and theirs else None
        result[name] = (ratio, {'you': mine, 'them': theirs})

    result['smoking'] = (1.0 if me.smoker == other.smoker else 0.5, {'you': me.smoker, 'them': other.smoker})

    city_a, city_b = me.user.city, other.user.city
    if city_a and city_b:
        km = distance_km(city_a, city_b)
        reference = me.max_distance_to_center or DEFAULT_DISTANCE_KM
        result['distance'] = (max(0.0, 1 - km / (2 * reference)), {'km': round(km, 1)})
    else:
        result['distance'] = (None, {'km': None})
    return result


def compute_match(me, other, language='en'):
    """Score 0-100, breakdown per criterion and a short explanation.
    A missing value counts as half the points (neutral)."""
    breakdown = {}
    total = 0.0
    for name, (ratio, details) in criteria(me, other).items():
        weight = WEIGHTS[name]
        points = weight * (0.5 if ratio is None else ratio)
        total += points
        breakdown[name] = {'points': round(points, 1), 'max': weight, 'known': ratio is not None, **details}
    score = max(0, min(100, round(total)))
    return {'score': score, 'breakdown': breakdown, 'explanation': explain(breakdown, language)}


# ---------------- Explanation (template; the AI version comes in Sprint 4) ----------------

CRITERIA_NAMES = {
    'en': {'budget': 'budget', 'sleep_schedule': 'sleep schedule', 'cleanliness': 'cleanliness',
           'noise_tolerance': 'noise tolerance', 'smoking': 'smoking', 'distance': 'distance'},
    'fr': {'budget': 'budget', 'sleep_schedule': 'rythme de sommeil', 'cleanliness': 'propreté',
           'noise_tolerance': 'tolérance au bruit', 'smoking': 'tabac', 'distance': 'distance'},
    'ar': {'budget': 'الميزانية', 'sleep_schedule': 'مواعيد النوم', 'cleanliness': 'النظافة',
           'noise_tolerance': 'تحمّل الضوضاء', 'smoking': 'التدخين', 'distance': 'المسافة'},
}
SENTENCES = {
    'en': {'strong': 'Good match on {items}.', 'weak': 'Different on {items}.', 'none': 'Few things in common.', 'sep': ', '},
    'fr': {'strong': 'Bonne compatibilité : {items}.', 'weak': 'Différences : {items}.', 'none': 'Peu de points communs.', 'sep': ', '},
    'ar': {'strong': 'توافق جيد في: {items}.', 'weak': 'اختلاف في: {items}.', 'none': 'القليل من القواسم المشتركة.', 'sep': '، '},
}


def explain(breakdown, language='en'):
    """'Good match on budget, cleanliness. Different on sleep schedule.' in the user's language."""
    names = CRITERIA_NAMES.get(language, CRITERIA_NAMES['en'])
    sentences = SENTENCES.get(language, SENTENCES['en'])
    known = [(name, item['points'] / item['max']) for name, item in breakdown.items() if item['known']]
    by_weight = sorted(known, key=lambda pair: WEIGHTS[pair[0]], reverse=True)
    strong = [names[name] for name, ratio in by_weight if ratio >= STRONG][:3]
    weak = [names[name] for name, ratio in by_weight if ratio <= WEAK][:2]

    text = sentences['strong'].format(items=sentences['sep'].join(strong)) if strong else sentences['none']
    if weak:
        text += ' ' + sentences['weak'].format(items=sentences['sep'].join(weak))
    return text


def rank_candidates(me, language='en'):
    """All compatible people for `me`, best score first: [(candidate profile, match dict), ...]."""
    results = [(other, compute_match(me, other, language)) for other in candidates_queryset(me)]
    results.sort(key=lambda pair: pair[1]['score'], reverse=True)
    return results

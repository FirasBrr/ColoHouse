from django.core.exceptions import ObjectDoesNotExist
from django.db import transaction
from django.db.models import Q
from django.http import Http404
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics, permissions
from rest_framework.response import Response

from accounts.models import RoommateProfile, User
from accounts.serializers import PublicUserSerializer
from housing.models import HousingRequest
from .engine import compute_match, incompatibilities, rank_candidates
from .models import MatchResult
from .serializers import MatchResultSerializer

DEFAULT_LIMIT = 20
MAX_LIMIT = 50


def my_profile(user):
    profile, _ = RoommateProfile.objects.select_related('user__city').get_or_create(user=user)
    return profile


def save_results(me, ranked):
    """Keeps one MatchResult per (me, candidate), in 2 queries: upsert the new results,
    delete the ones of people who no longer pass the filters."""
    now = timezone.now()
    results = [
        MatchResult(requester=me, candidate=other, computed_at=now, **match)
        for other, match in ranked
    ]
    with transaction.atomic():
        MatchResult.objects.bulk_create(
            results,
            update_conflicts=True,
            unique_fields=['requester', 'candidate'],
            update_fields=['score', 'breakdown', 'explanation', 'computed_at'],
        )
        MatchResult.objects.filter(requester=me).exclude(computed_at=now).delete()
    return results


class MatchListView(generics.ListAPIView):
    """Compatible roommates, best score first. Optional ?limit=20 (max 50) and ?min_score=60."""
    serializer_class = MatchResultSerializer
    permission_classes = [permissions.IsAuthenticated]

    def list(self, request, *args, **kwargs):
        me = my_profile(request.user)
        results = save_results(me, rank_candidates(me, request.user.language))

        min_score = request.query_params.get('min_score', '')
        if min_score.isdigit():
            results = [result for result in results if result.score >= int(min_score)]
        limit = request.query_params.get('limit', '')
        limit = min(int(limit), MAX_LIMIT) if limit.isdigit() and int(limit) > 0 else DEFAULT_LIMIT
        return Response(self.get_serializer(results[:limit], many=True).data)


def shares_a_request(user, other_user):
    """True when one of them sent a housing request on a listing of the other."""
    return HousingRequest.objects.filter(
        Q(sender=user, listing__owner=other_user) | Q(sender=other_user, listing__owner=user)
    ).exists()


class MatchDetailView(generics.GenericAPIView):
    """Compatibility with one person, even if a hard filter fails (`compatible` + `reasons` say why).

    Privacy: only for people who opted in to matching (looking_for_room) or who share a housing
    request with me (e.g. the host checking who sent a request); 404 for everyone else.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, user_id):
        other_user = get_object_or_404(
            User.objects.select_related('city').exclude(pk=request.user.pk), pk=user_id, is_active=True
        )
        try:
            other = other_user.roommate_profile
        except ObjectDoesNotExist:
            # Preferences never filled in: every criterion counts as "missing" (half points)
            other = RoommateProfile(user=other_user)
        if not (other.looking_for_room or shares_a_request(request.user, other_user)):
            raise Http404

        me = my_profile(request.user)
        match = compute_match(me, other, request.user.language)
        reasons = [reason for reason in incompatibilities(me, other) if reason != 'not_looking']
        return Response({
            'user': PublicUserSerializer(other_user, context={'request': request}).data,
            'city': other_user.city.name if other_user.city else None,
            'compatible': not reasons,
            'reasons': reasons,
            **match,
            'computed_at': timezone.now(),
        })

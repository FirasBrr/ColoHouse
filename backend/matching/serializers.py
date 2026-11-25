from rest_framework import serializers

from accounts.serializers import PublicUserSerializer
from .models import MatchResult


class MatchResultSerializer(serializers.ModelSerializer):
    user = PublicUserSerializer(source='candidate.user', read_only=True)
    city = serializers.CharField(source='candidate.user.city.name', default=None, read_only=True)

    class Meta:
        model = MatchResult
        fields = ['user', 'city', 'score', 'breakdown', 'explanation', 'computed_at']

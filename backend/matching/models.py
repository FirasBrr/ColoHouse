from django.db import models
from django.utils import timezone

from accounts.models import RoommateProfile


class MatchResult(models.Model):
    """How compatible a candidate is for a requester: score 0-100 + breakdown per criterion.
    Saved every time the requester's match list is computed."""
    requester = models.ForeignKey(
        RoommateProfile, on_delete=models.CASCADE, related_name='matches_requested'
    )
    candidate = models.ForeignKey(
        RoommateProfile, on_delete=models.CASCADE, related_name='matches_as_candidate'
    )
    score = models.PositiveSmallIntegerField()
    breakdown = models.JSONField(default=dict)
    explanation = models.CharField(max_length=300, blank=True)
    computed_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ['-score', '-computed_at']
        constraints = [
            models.UniqueConstraint(fields=['requester', 'candidate'], name='one_result_per_pair'),
        ]

    def __str__(self):
        return f"{self.requester.user} / {self.candidate.user}: {self.score}"

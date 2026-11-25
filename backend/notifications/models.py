from django.conf import settings
from django.db import models
from django.utils import timezone


class NotificationType(models.TextChoices):
    HOUSING_REQUEST = 'housing_request', 'New housing request'
    REQUEST_ACCEPTED = 'request_accepted', 'Request accepted'
    REQUEST_DECLINED = 'request_declined', 'Request declined'
    NEW_MESSAGE = 'new_message', 'New message'


class Notification(models.Model):
    """One entry of a user's notification history (also sent as a push when the user allows it)."""
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notifications'
    )
    type = models.CharField(max_length=20, choices=NotificationType.choices)
    title = models.CharField(max_length=120)
    body = models.CharField(max_length=300)
    # Where a tap leads in the app, e.g. {"screen": "conversation", "conversation_id": 3}
    data = models.JSONField(default=dict, blank=True)
    # Notifications of the same group are merged while unread (e.g. several messages of one chat)
    group = models.CharField(max_length=64, blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['user', 'is_read'])]

    def __str__(self):
        return f"{self.user} - {self.title}"

    def mark_as_read(self):
        if not self.is_read:
            self.is_read = True
            self.save(update_fields=['is_read'])

import uuid

from django.conf import settings
from django.db import models
from django.db.models import F


class Conversation(models.Model):
    """One chat per accepted housing request (created when the host accepts).

    The messages live in Cloud Firestore at conversations/<id>/messages (real time);
    this row lists the chats in the app and keeps the last message for the list.
    """
    request = models.OneToOneField(
        'housing.HousingRequest', on_delete=models.CASCADE, related_name='conversation'
    )
    # Random id of the Firestore document: two databases (each teammate's, or after a reset)
    # never point to the same chat, unlike the auto-increment id
    firestore_id = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    last_message = models.CharField(max_length=200, blank=True)
    last_message_at = models.DateTimeField(null=True, blank=True)
    last_message_id = models.CharField(max_length=128, blank=True)
    last_sender = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='+'
    )

    class Meta:
        ordering = [F('last_message_at').desc(nulls_last=True), '-created_at']

    def __str__(self):
        return f"Conversation about {self.request.listing}"

    @property
    def firestore_path(self):
        return f'conversations/{self.firestore_id}'

    def participants(self):
        """The two people of the chat: the listing owner and the person who sent the request."""
        return self.request.listing.owner, self.request.sender

    def other_participant(self, user):
        owner, sender = self.participants()
        return sender if user == owner else owner

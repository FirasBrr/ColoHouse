from django.conf import settings
from django.db import transaction
from django.db.models import Q
from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver

from .firestore import try_delete_conversation, try_sync_conversation
from .models import Conversation


@receiver(post_delete, sender=Conversation)
def delete_firestore_chat(sender, instance, **kwargs):
    """A conversation deleted in Django (e.g. account deleted, which cascades) is erased from
    Firestore too, after the database commit."""
    firestore_id = instance.firestore_id
    transaction.on_commit(lambda: try_delete_conversation(firestore_id))


@receiver(post_save, sender=settings.AUTH_USER_MODEL)
def remove_deactivated_user_from_chats(sender, instance, **kwargs):
    """A deactivated account loses access to its chats (its uid leaves `participants`)."""
    if instance.is_active:
        return
    conversations = Conversation.objects.filter(
        Q(request__sender=instance) | Q(request__listing__owner=instance)
    ).select_related('request__sender', 'request__listing__owner')
    for conversation in conversations:
        transaction.on_commit(lambda conversation=conversation: try_sync_conversation(conversation))

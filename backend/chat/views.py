from datetime import datetime

from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics, permissions
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response

from notifications.models import Notification, NotificationType
from notifications.services import notify
from notifications.texts import display_name
from .firestore import get_message, sync_conversation
from .models import Conversation
from .serializers import ConversationSerializer, MessageSentSerializer


def message_group(conversation):
    """Group of the 'new message' notifications of one chat (merged while unread)."""
    return f'conversation-{conversation.pk}'


def my_conversations(user):
    return Conversation.objects.filter(
        Q(request__sender=user) | Q(request__listing__owner=user)
    ).select_related(
        'request__sender', 'request__listing__owner', 'request__listing__city'
    ).prefetch_related('request__listing__photos')


class ConversationListView(generics.ListAPIView):
    """My chats, the most recent message first."""
    serializer_class = ConversationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return my_conversations(self.request.user)


class ConversationDetailView(generics.RetrieveAPIView):
    """Called when the app opens a chat: makes sure the Firestore document exists with both
    participants, then the app listens to firestore_path + '/messages'."""
    serializer_class = ConversationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return my_conversations(self.request.user)

    def retrieve(self, request, *args, **kwargs):
        conversation = self.get_object()
        if not request.user.firebase_uid:
            raise ValidationError({'non_field_errors': ['Log in with Firebase (email or Google) to use the chat.']})
        sync_conversation(conversation)
        # Opening the chat = its message notifications are read (bell badge)
        Notification.objects.filter(
            user=request.user, group=message_group(conversation), is_read=False
        ).update(is_read=True)
        return Response(self.get_serializer(conversation).data)


class MessageSentView(generics.GenericAPIView):
    """The app calls this right after writing a message in Firestore.
    The server reads the message there (so nobody can fake its content), updates the chat list
    and notifies the other person."""
    serializer_class = MessageSentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        conversation = get_object_or_404(my_conversations(request.user), pk=pk)
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        message_id = serializer.validated_data['message_id']

        if conversation.last_message_id == message_id:
            return Response({'notified': False})
        message = get_message(conversation, message_id)
        if message is None:
            raise ValidationError({'message_id': ['This message does not exist in the chat.']})
        if not request.user.firebase_uid or message.get('sender_uid') != request.user.firebase_uid:
            raise PermissionDenied('This message was not sent by you.')

        text = str(message.get('text', ''))[:200]
        sent_at = message.get('sent_at')
        if not isinstance(sent_at, datetime):
            sent_at = timezone.now()
        # Only a message newer than the last one counts: a retry or a replay of an older
        # message neither moves the chat list back nor sends the push again
        updated = Conversation.objects.filter(pk=conversation.pk).filter(
            Q(last_message_at__isnull=True) | Q(last_message_at__lt=sent_at)
        ).update(last_message=text, last_message_at=sent_at, last_message_id=message_id, last_sender=request.user)
        if not updated:
            return Response({'notified': False})

        receiver = conversation.other_participant(request.user)
        notify(
            receiver,
            NotificationType.NEW_MESSAGE,
            data={'screen': 'conversation', 'conversation_id': conversation.pk},
            group=message_group(conversation),
            sender=display_name(request.user, receiver.language),
            text=text,
        )
        return Response({'notified': True})

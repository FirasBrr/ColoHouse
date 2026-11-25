from django.core.validators import RegexValidator
from rest_framework import serializers

from accounts.serializers import PublicUserSerializer
from housing.serializers import ListingSummarySerializer
from .models import Conversation


class ConversationSerializer(serializers.ModelSerializer):
    listing = ListingSummarySerializer(source='request.listing', read_only=True)
    other_user = serializers.SerializerMethodField()
    firestore_path = serializers.CharField(read_only=True)

    class Meta:
        model = Conversation
        fields = [
            'id', 'request_id', 'listing', 'other_user',
            'last_message', 'last_message_at', 'last_sender_id',
            'firestore_path', 'created_at',
        ]

    def get_other_user(self, conversation):
        other = conversation.other_participant(self.context['request'].user)
        return PublicUserSerializer(other, context=self.context).data


class MessageSentSerializer(serializers.Serializer):
    """The id of the Firestore message the app just wrote (no '/' allowed: it is a document id)."""
    message_id = serializers.CharField(
        max_length=128,
        validators=[RegexValidator(r'^[A-Za-z0-9_-]+$', 'Invalid message id.')],
    )

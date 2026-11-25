from rest_framework import serializers
from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id', 'type', 'title', 'body', 'data', 'is_read', 'created_at']
        read_only_fields = fields


class DeviceSerializer(serializers.Serializer):
    """The phone's push token, from FirebaseMessaging.instance.getToken() in the app."""
    fcm_token = serializers.CharField(max_length=512)

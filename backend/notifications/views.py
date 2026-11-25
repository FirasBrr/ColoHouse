from django.contrib.auth import get_user_model
from django.db import transaction
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.response import Response

from .models import Notification
from .serializers import DeviceSerializer, NotificationSerializer

MAX_NOTIFICATIONS = 100


class NotificationListView(generics.ListAPIView):
    """My notification history, newest first (the last 100). Optional ?unread=true."""
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = Notification.objects.filter(user=self.request.user)
        if self.request.query_params.get('unread') == 'true':
            queryset = queryset.filter(is_read=False)
        return queryset[:MAX_NOTIFICATIONS]


class UnreadCountView(generics.GenericAPIView):
    """Number for the red badge on the bell icon."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        count = Notification.objects.filter(user=request.user, is_read=False).count()
        return Response({'unread': count})


class MarkReadView(generics.GenericAPIView):
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        notification = get_object_or_404(Notification, pk=pk, user=request.user)
        notification.mark_as_read()
        return Response(self.get_serializer(notification).data)


class MarkAllReadView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        updated = Notification.objects.filter(user=request.user, is_read=False).update(is_read=True)
        return Response({'updated': updated})


class DeviceView(generics.GenericAPIView):
    """POST = this phone receives my pushes (after login / when the token changes).
    DELETE = stop sending pushes to this phone (on logout). With {"fcm_token": ...} only that phone's
    token is removed, so logging out on an old phone does not stop the pushes on the new one."""
    serializer_class = DeviceSerializer
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        token = serializer.validated_data['fcm_token']
        with transaction.atomic():
            # One phone = one account: if someone else logged in on this phone before, they stop getting its pushes
            get_user_model().objects.filter(fcm_token=token).exclude(pk=request.user.pk).update(fcm_token='')
            request.user.fcm_token = token
            request.user.save(update_fields=['fcm_token'])
        return Response({'fcm_token': token})

    def delete(self, request):
        users = get_user_model().objects.filter(pk=request.user.pk)
        token = request.data.get('fcm_token') if hasattr(request.data, 'get') else None
        if token:
            users = users.filter(fcm_token=token)
        users.update(fcm_token='')
        return Response(status=status.HTTP_204_NO_CONTENT)

from django.urls import path
from . import views

app_name = 'notifications'

urlpatterns = [
    path('notifications/', views.NotificationListView.as_view(), name='list'),
    path('notifications/unread-count/', views.UnreadCountView.as_view(), name='unread_count'),
    path('notifications/<int:pk>/read/', views.MarkReadView.as_view(), name='mark_read'),
    path('notifications/read-all/', views.MarkAllReadView.as_view(), name='mark_all_read'),
    path('notifications/device/', views.DeviceView.as_view(), name='device'),
]

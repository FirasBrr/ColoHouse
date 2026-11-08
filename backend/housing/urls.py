from django.urls import path
from . import views

app_name = 'housing'

urlpatterns = [
    path('listings/', views.ListingListCreateView.as_view(), name='listings'),
    path('listings/mine/', views.MyListingsView.as_view(), name='my_listings'),
    path('listings/<int:pk>/', views.ListingDetailView.as_view(), name='listing_detail'),
    path('listings/<int:pk>/photos/', views.ListingPhotoCreateView.as_view(), name='listing_photos'),
    path('listings/<int:pk>/photos/<int:photo_pk>/', views.ListingPhotoDeleteView.as_view(), name='listing_photo_delete'),
    path('listings/<int:pk>/requests/', views.SendRequestView.as_view(), name='send_request'),
    path('requests/sent/', views.SentRequestsView.as_view(), name='sent_requests'),
    path('requests/received/', views.ReceivedRequestsView.as_view(), name='received_requests'),
    path('requests/<int:pk>/accept/', views.AcceptRequestView.as_view(), name='accept_request'),
    path('requests/<int:pk>/decline/', views.DeclineRequestView.as_view(), name='decline_request'),
    path('requests/<int:pk>/cancel/', views.CancelRequestView.as_view(), name='cancel_request'),
]

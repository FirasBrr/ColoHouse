from django.urls import path
from . import views

app_name = 'matching'

urlpatterns = [
    path('matches/', views.MatchListView.as_view(), name='matches'),
    path('matches/<int:user_id>/', views.MatchDetailView.as_view(), name='match_detail'),
]

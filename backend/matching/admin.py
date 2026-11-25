from django.contrib import admin
from .models import MatchResult


@admin.register(MatchResult)
class MatchResultAdmin(admin.ModelAdmin):
    list_display = ['requester', 'candidate', 'score', 'computed_at']
    search_fields = ['requester__user__email', 'candidate__user__email']

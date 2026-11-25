from django.contrib import admin
from .models import Conversation


@admin.register(Conversation)
class ConversationAdmin(admin.ModelAdmin):
    list_display = ['request', 'last_message', 'last_message_at', 'created_at']
    search_fields = ['request__listing__title', 'request__sender__email']
    readonly_fields = ['last_message_id']

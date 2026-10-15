from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import City, RoommateProfile, User


@admin.register(User)
class CustomUserAdmin(UserAdmin):
    ordering = ['email']
    list_display = [
        'email', 'first_name', 'last_name',
        'institution', 'city', 'is_verified', 'is_staff',
    ]
    list_filter = ['is_verified', 'is_staff', 'is_superuser']
    search_fields = ['email', 'first_name', 'last_name']
    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Personal info', {
            'fields': ('first_name', 'last_name', 'phone',
                       'profile_picture', 'bio')
        }),
        ('Background', {
            'fields': ('institution', 'occupation', 'city')
        }),
        ('Verification', {
            'fields': ('is_verified',),
            'description': 'Check this box to verify the user. '
                           'Users cannot change this themselves.'
        }),
        ('Notifications', {
            'fields': ('push_enabled', 'notify_requests', 'notify_messages')
        }),
        ('Permissions', {
            'fields': ('is_active', 'is_staff', 'is_superuser',
                       'groups', 'user_permissions')
        }),
        ('Important dates', {'fields': ('last_login', 'date_joined')}),
    )
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'first_name', 'last_name',
                       'usable_password', 'password1', 'password2'),
        }),
    )
    actions = ['mark_verified', 'mark_unverified']

    @admin.action(description='✅ Mark selected users as verified')
    def mark_verified(self, request, queryset):
        updated = queryset.update(is_verified=True)
        self.message_user(request, f'{updated} user(s) marked as verified.')

    @admin.action(description='❌ Mark selected users as unverified')
    def mark_unverified(self, request, queryset):
        updated = queryset.update(is_verified=False)
        self.message_user(request, f'{updated} user(s) marked as unverified.')


admin.site.register(City)
admin.site.register(RoommateProfile)
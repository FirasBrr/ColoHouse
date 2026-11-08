from django.contrib import admin
from .models import HousingListing, HousingRequest, ListingPhoto, ListingStatus


class ListingPhotoInline(admin.TabularInline):
    model = ListingPhoto
    extra = 0


@admin.register(HousingListing)
class HousingListingAdmin(admin.ModelAdmin):
    list_display = ['title', 'owner', 'rent', 'room_type', 'city', 'status', 'created_at']
    list_filter = ['status', 'room_type', 'city']
    search_fields = ['title', 'address', 'owner__email']
    inlines = [ListingPhotoInline]
    actions = ['approve', 'hide']

    @admin.action(description='✅ Approve selected listings (set active)')
    def approve(self, request, queryset):
        updated = queryset.update(status=ListingStatus.ACTIVE)
        self.message_user(request, f'{updated} listing(s) approved.')

    @admin.action(description='🚫 Hide selected listings')
    def hide(self, request, queryset):
        updated = queryset.update(status=ListingStatus.HIDDEN)
        self.message_user(request, f'{updated} listing(s) hidden.')


@admin.register(HousingRequest)
class HousingRequestAdmin(admin.ModelAdmin):
    list_display = ['listing', 'sender', 'status', 'created_at']
    list_filter = ['status']
    search_fields = ['listing__title', 'sender__email']


admin.site.register(ListingPhoto)

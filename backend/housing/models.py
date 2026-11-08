from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

from accounts.models import City, RoomType


class ListingStatus(models.TextChoices):
    DRAFT = 'draft', 'Draft'
    PENDING_REVIEW = 'pending_review', 'Pending review'
    ACTIVE = 'active', 'Active'
    PAUSED = 'paused', 'Paused'
    CLOSED = 'closed', 'Closed'
    HIDDEN = 'hidden', 'Hidden by admin'


# Status changes the owner is allowed to make himself.
# pending_review / hidden are admin-only (Django admin actions).
OWNER_STATUS_TRANSITIONS = {
    ListingStatus.DRAFT: [ListingStatus.ACTIVE, ListingStatus.CLOSED],
    ListingStatus.ACTIVE: [ListingStatus.PAUSED, ListingStatus.CLOSED],
    ListingStatus.PAUSED: [ListingStatus.ACTIVE, ListingStatus.CLOSED],
}


class HousingListing(models.Model):
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='listings'
    )
    title = models.CharField(max_length=120)
    description = models.TextField(max_length=3000)
    rent = models.PositiveIntegerField(validators=[MinValueValidator(1)])
    deposit = models.PositiveIntegerField(default=0)
    room_type = models.CharField(max_length=10, choices=RoomType.choices)

    city = models.ForeignKey(
        City, on_delete=models.SET_NULL, null=True, blank=True, related_name='listings'
    )
    # Exact address: only shown to the owner and to users with an accepted request
    address = models.CharField(max_length=255)
    latitude = models.FloatField(validators=[MinValueValidator(-90), MaxValueValidator(90)])
    longitude = models.FloatField(validators=[MinValueValidator(-180), MaxValueValidator(180)])

    available_from = models.DateField()
    rules = models.TextField(max_length=1000, blank=True)
    status = models.CharField(
        max_length=20, choices=ListingStatus.choices, default=ListingStatus.ACTIVE
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        # Indexes for the search filters (status + price, map box, availability)
        indexes = [
            models.Index(fields=['status', 'rent']),
            models.Index(fields=['latitude', 'longitude']),
            models.Index(fields=['available_from']),
        ]

    def __str__(self):
        return self.title


class ListingPhoto(models.Model):
    listing = models.ForeignKey(HousingListing, on_delete=models.CASCADE, related_name='photos')
    image = models.ImageField(upload_to='listing_photos/')
    order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ['order', 'id']

    def __str__(self):
        return f"Photo {self.order} of {self.listing}"


class RequestStatus(models.TextChoices):
    PENDING = 'pending', 'Pending'
    ACCEPTED = 'accepted', 'Accepted'
    DECLINED = 'declined', 'Declined'
    CANCELLED = 'cancelled', 'Cancelled'
    COMPLETED = 'completed', 'Completed'


class HousingRequest(models.Model):
    """Association class between a student (sender) and a listing."""
    listing = models.ForeignKey(HousingListing, on_delete=models.CASCADE, related_name='requests')
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='housing_requests'
    )
    message = models.TextField(max_length=1000, blank=True)
    status = models.CharField(
        max_length=10, choices=RequestStatus.choices, default=RequestStatus.PENDING
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        constraints = [
            # A student can only have one open (pending or accepted) request per listing
            models.UniqueConstraint(
                fields=['listing', 'sender'],
                condition=models.Q(status__in=['pending', 'accepted']),
                name='one_open_request_per_listing',
            ),
        ]

    def __str__(self):
        return f"{self.sender} -> {self.listing} ({self.status})"

    def _set_status(self, status):
        self.status = status
        self.save(update_fields=['status', 'updated_at'])

    def accept(self):
        self._set_status(RequestStatus.ACCEPTED)

    def decline(self):
        self._set_status(RequestStatus.DECLINED)

    def cancel(self):
        self._set_status(RequestStatus.CANCELLED)

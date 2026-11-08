from rest_framework import serializers

from accounts.models import City, RoomType
from accounts.serializers import CitySerializer, PublicUserSerializer
from .models import (
    OWNER_STATUS_TRANSITIONS,
    HousingListing,
    HousingRequest,
    ListingPhoto,
    ListingStatus,
    RequestStatus,
)
from .search import ORDERINGS

MAX_PHOTO_SIZE = 5 * 1024 * 1024


class ListingPhotoSerializer(serializers.ModelSerializer):
    class Meta:
        model = ListingPhoto
        fields = ['id', 'image', 'order']
        read_only_fields = ['order']

    def validate_image(self, value):
        if value.size > MAX_PHOTO_SIZE:
            raise serializers.ValidationError('The photo must be smaller than 5 MB.')
        return value


class ListingSerializer(serializers.ModelSerializer):
    owner = PublicUserSerializer(read_only=True)
    city = CitySerializer(read_only=True)
    city_id = serializers.PrimaryKeyRelatedField(
        queryset=City.objects.all(),
        source='city',
        write_only=True,
        allow_null=True,
        required=False,
    )
    photos = ListingPhotoSerializer(many=True, read_only=True)
    distance_km = serializers.SerializerMethodField()
    contact_visible = serializers.SerializerMethodField()
    owner_phone = serializers.SerializerMethodField()
    my_request = serializers.SerializerMethodField()

    class Meta:
        model = HousingListing
        fields = [
            'id', 'owner', 'title', 'description', 'rent', 'deposit', 'room_type',
            'city', 'city_id', 'address', 'latitude', 'longitude', 'distance_km',
            'available_from', 'rules', 'status', 'photos',
            'contact_visible', 'owner_phone', 'my_request',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']

    def _my_request(self, listing):
        # Filled once by the view (ListingContextMixin) to avoid one query per listing
        return self.context.get('my_requests', {}).get(listing.id)

    def get_contact_visible(self, listing):
        if listing.owner_id == self.context['request'].user.id:
            return True
        my_request = self._my_request(listing)
        return my_request is not None and my_request.status == RequestStatus.ACCEPTED

    def get_owner_phone(self, listing):
        return listing.owner.phone if self.get_contact_visible(listing) else None

    def get_distance_km(self, listing):
        distance = getattr(listing, 'distance_km', None)
        return round(distance, 2) if distance is not None else None

    def get_my_request(self, listing):
        my_request = self._my_request(listing)
        if my_request is None:
            return None
        return {'id': my_request.id, 'status': my_request.status}

    def to_representation(self, listing):
        data = super().to_representation(listing)
        if not data['contact_visible']:
            # Hide the exact address; coordinates rounded to ~1 km for the map
            data['address'] = None
            data['latitude'] = round(listing.latitude, 2)
            data['longitude'] = round(listing.longitude, 2)
        return data

    def validate_status(self, value):
        if self.instance is None:
            if value not in (ListingStatus.DRAFT, ListingStatus.ACTIVE):
                raise serializers.ValidationError('A new listing can only be a draft or active.')
            return value
        current = self.instance.status
        if value != current and value not in OWNER_STATUS_TRANSITIONS.get(current, []):
            raise serializers.ValidationError(f'You cannot change a {current} listing to {value}.')
        return value


class ListingSummarySerializer(serializers.ModelSerializer):
    """Small version of a listing, used inside requests."""
    city = serializers.CharField(source='city.name', default=None, read_only=True)
    photo = serializers.SerializerMethodField()

    class Meta:
        model = HousingListing
        fields = ['id', 'title', 'rent', 'room_type', 'city', 'status', 'photo']

    def get_photo(self, listing):
        photos = list(listing.photos.all())
        if not photos:
            return None
        return self.context['request'].build_absolute_uri(photos[0].image.url)


class HousingRequestSerializer(serializers.ModelSerializer):
    listing = ListingSummarySerializer(read_only=True)
    sender = PublicUserSerializer(read_only=True)
    owner = PublicUserSerializer(source='listing.owner', read_only=True)
    contact = serializers.SerializerMethodField()

    class Meta:
        model = HousingRequest
        fields = [
            'id', 'listing', 'sender', 'owner', 'message', 'status',
            'contact', 'created_at', 'updated_at',
        ]
        read_only_fields = ['status', 'created_at', 'updated_at']

    def get_contact(self, housing_request):
        """Address and phones are only shared once the request is accepted."""
        if housing_request.status != RequestStatus.ACCEPTED:
            return None
        listing = housing_request.listing
        return {
            'address': listing.address,
            'latitude': listing.latitude,
            'longitude': listing.longitude,
            'owner_phone': listing.owner.phone,
            'sender_phone': housing_request.sender.phone,
        }


class ListingSearchSerializer(serializers.Serializer):
    """Validates the query params of GET /api/listings/ (like a search form)."""
    q = serializers.CharField(required=False, allow_blank=True, max_length=100)
    city = serializers.IntegerField(required=False, min_value=1)
    room_type = serializers.ChoiceField(choices=RoomType.choices, required=False)
    min_rent = serializers.IntegerField(required=False, min_value=0)
    max_rent = serializers.IntegerField(required=False, min_value=0)
    available_by = serializers.DateField(required=False)
    lat = serializers.FloatField(required=False, min_value=-90, max_value=90)
    lng = serializers.FloatField(required=False, min_value=-180, max_value=180)
    radius_km = serializers.FloatField(required=False, min_value=0.1, max_value=100)
    ordering = serializers.ChoiceField(choices=list(ORDERINGS), required=False, default='newest')

    def validate(self, data):
        if ('lat' in data) != ('lng' in data):
            raise serializers.ValidationError({'lat': ['Send both lat and lng.']})
        if 'min_rent' in data and 'max_rent' in data and data['min_rent'] > data['max_rent']:
            raise serializers.ValidationError({'min_rent': ['min_rent must be lower than max_rent.']})
        return data

from django.db import transaction
from django.db.models import Q
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions
from rest_framework.exceptions import ValidationError
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response

from .models import HousingListing, HousingRequest, ListingPhoto, ListingStatus, RequestStatus
from .permissions import IsOwnerOrReadOnly
from .search import search_listings
from .serializers import (
    HousingRequestSerializer,
    ListingPhotoSerializer,
    ListingSearchSerializer,
    ListingSerializer,
)

MAX_PHOTOS_PER_LISTING = 8


def listing_queryset():
    return HousingListing.objects.select_related('owner', 'city').prefetch_related('photos')


def request_queryset():
    return HousingRequest.objects.select_related(
        'listing__owner', 'listing__city', 'sender'
    ).prefetch_related('listing__photos')


class ListingContextMixin:
    """Gives the serializer the current user's requests (1 query instead of 1 per listing)."""

    def get_serializer_context(self):
        context = super().get_serializer_context()
        my_requests = {}
        for housing_request in HousingRequest.objects.filter(sender=self.request.user).order_by('created_at'):
            my_requests[housing_request.listing_id] = housing_request
        context['my_requests'] = my_requests
        return context


# ---------------- Listings ----------------

class ListingListCreateView(ListingContextMixin, generics.ListCreateAPIView):
    """GET = search active listings (filters in query params), POST = publish a listing."""
    serializer_class = ListingSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        params = ListingSearchSerializer(data=self.request.query_params)
        params.is_valid(raise_exception=True)
        queryset = listing_queryset().filter(status=ListingStatus.ACTIVE)
        return search_listings(queryset, params.validated_data)

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)


class MyListingsView(ListingContextMixin, generics.ListAPIView):
    serializer_class = ListingSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return listing_queryset().filter(owner=self.request.user)


class ListingDetailView(ListingContextMixin, generics.RetrieveUpdateAPIView):
    """No DELETE: the owner closes a listing instead (keeps the request history)."""
    serializer_class = ListingSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrReadOnly]

    def get_queryset(self):
        user = self.request.user
        return listing_queryset().filter(
            Q(status=ListingStatus.ACTIVE)
            | Q(owner=user)
            | Q(requests__sender=user, requests__status=RequestStatus.ACCEPTED)
        ).distinct()


# ---------------- Photos ----------------

class ListingPhotoCreateView(generics.CreateAPIView):
    serializer_class = ListingPhotoSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def perform_create(self, serializer):
        listing = get_object_or_404(HousingListing, pk=self.kwargs['pk'], owner=self.request.user)
        count = listing.photos.count()
        if count >= MAX_PHOTOS_PER_LISTING:
            raise ValidationError({'image': [f'A listing can have at most {MAX_PHOTOS_PER_LISTING} photos.']})
        serializer.save(listing=listing, order=count)


class ListingPhotoDeleteView(generics.DestroyAPIView):
    permission_classes = [permissions.IsAuthenticated]
    lookup_url_kwarg = 'photo_pk'

    def get_queryset(self):
        return ListingPhoto.objects.filter(
            listing_id=self.kwargs['pk'], listing__owner=self.request.user
        )

    def perform_destroy(self, photo):
        photo.image.delete(save=False)
        photo.delete()


# ---------------- Requests ----------------

class SendRequestView(generics.CreateAPIView):
    serializer_class = HousingRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        user = self.request.user
        listing = get_object_or_404(HousingListing, pk=self.kwargs['pk'], status=ListingStatus.ACTIVE)
        if listing.owner_id == user.id:
            raise ValidationError({'non_field_errors': ['You cannot send a request to your own listing.']})
        open_statuses = [RequestStatus.PENDING, RequestStatus.ACCEPTED]
        if listing.requests.filter(sender=user, status__in=open_statuses).exists():
            raise ValidationError({'non_field_errors': ['You already have an open request for this listing.']})
        serializer.save(listing=listing, sender=user)


class SentRequestsView(generics.ListAPIView):
    serializer_class = HousingRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = request_queryset().filter(sender=self.request.user)
        status = self.request.query_params.get('status')
        return queryset.filter(status=status) if status else queryset


class ReceivedRequestsView(generics.ListAPIView):
    """Requests on my listings. Optional ?status=pending and ?listing=<id>."""
    serializer_class = HousingRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = request_queryset().filter(listing__owner=self.request.user)
        status = self.request.query_params.get('status')
        listing = self.request.query_params.get('listing')
        if status:
            queryset = queryset.filter(status=status)
        if listing and listing.isdigit():
            queryset = queryset.filter(listing_id=listing)
        return queryset


class RequestActionView(generics.GenericAPIView):
    """Base for accept / decline / cancel.

    The request row is locked (select_for_update) inside a transaction, so two
    clicks at the same time (e.g. accept + decline) cannot both succeed.
    """
    serializer_class = HousingRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def apply(self, housing_request):
        raise NotImplementedError

    def post(self, request, pk):
        with transaction.atomic():
            housing_request = get_object_or_404(self.get_queryset().select_for_update(), pk=pk)
            if housing_request.status != RequestStatus.PENDING:
                raise ValidationError(
                    {'non_field_errors': [f'This request is already {housing_request.status}.']}
                )
            self.apply(housing_request)
        return Response(self.get_serializer(housing_request).data)


class AcceptRequestView(RequestActionView):
    def get_queryset(self):
        return HousingRequest.objects.filter(listing__owner=self.request.user)

    def apply(self, housing_request):
        if housing_request.listing.status != ListingStatus.ACTIVE:
            raise ValidationError({'non_field_errors': ['You can only accept requests on an active listing.']})
        housing_request.accept()


class DeclineRequestView(RequestActionView):
    def get_queryset(self):
        return HousingRequest.objects.filter(listing__owner=self.request.user)

    def apply(self, housing_request):
        housing_request.decline()


class CancelRequestView(RequestActionView):
    def get_queryset(self):
        return HousingRequest.objects.filter(sender=self.request.user)

    def apply(self, housing_request):
        housing_request.cancel()

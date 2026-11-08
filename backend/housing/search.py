import math

from django.db.models import Q
from django.db.models.functions import ASin, Cos, Power, Radians, Sin, Sqrt
from rest_framework.exceptions import ValidationError

from accounts.models import City

EARTH_RADIUS_KM = 6371.0
KM_PER_DEGREE = 111.0

ORDERINGS = {
    'newest': '-created_at',
    'rent': 'rent',
    '-rent': '-rent',
    'distance': 'distance_km',
}


def annotate_distance(queryset, lat, lng):
    """Adds distance_km to every listing (Haversine formula, computed by the database)."""
    lat1 = math.radians(lat)
    lng1 = math.radians(lng)
    lat2 = Radians('latitude')
    lng2 = Radians('longitude')
    a = (
        Power(Sin((lat2 - lat1) / 2.0), 2)
        + math.cos(lat1) * Cos(lat2) * Power(Sin((lng2 - lng1) / 2.0), 2)
    )
    return queryset.annotate(distance_km=2.0 * EARTH_RADIUS_KM * ASin(Sqrt(a)))


def search_listings(queryset, params):
    """Applies the search filters. `params` are the validated query params."""
    if params.get('q'):
        queryset = queryset.filter(
            Q(title__icontains=params['q']) | Q(description__icontains=params['q'])
        )
    if 'city' in params:
        queryset = queryset.filter(city_id=params['city'])
    if 'room_type' in params:
        queryset = queryset.filter(room_type=params['room_type'])
    if 'min_rent' in params:
        queryset = queryset.filter(rent__gte=params['min_rent'])
    if 'max_rent' in params:
        queryset = queryset.filter(rent__lte=params['max_rent'])
    if 'available_by' in params:
        queryset = queryset.filter(available_from__lte=params['available_by'])

    # Distance: from the point sent by the app (lat/lng), otherwise from the city center
    center = None
    if 'lat' in params:
        center = (params['lat'], params['lng'])
    elif 'city' in params:
        city = City.objects.filter(pk=params['city']).first()
        if city:
            center = (city.latitude, city.longitude)

    radius = params.get('radius_km')
    if center is None and (radius or params['ordering'] == 'distance'):
        raise ValidationError({'radius_km': ['Send lat and lng (or a city) to search by distance.']})

    if center:
        lat, lng = center
        if radius:
            # Cheap box filter first (uses the latitude/longitude index), exact distance after
            lat_delta = radius / KM_PER_DEGREE
            lng_delta = radius / (KM_PER_DEGREE * max(math.cos(math.radians(lat)), 0.01))
            queryset = queryset.filter(
                latitude__range=(lat - lat_delta, lat + lat_delta),
                longitude__range=(lng - lng_delta, lng + lng_delta),
            )
        queryset = annotate_distance(queryset, lat, lng)
        if radius:
            queryset = queryset.filter(distance_km__lte=radius)

    return queryset.order_by(ORDERINGS[params['ordering']])

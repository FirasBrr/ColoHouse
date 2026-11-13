// Search filters for GET /api/listings/ (see backend README "Search listings").
// Used as a Riverpod family key, so it must stay immutable with a value ==.

const _unset = Object();

class ListingFilters {
  static const orderings = ['newest', 'rent', '-rent', 'distance'];
  static const roomTypes = ['private', 'shared', 'studio'];

  final String query;
  final int? cityId;
  final String? roomType; // private | shared | studio
  final int? minRent;
  final int? maxRent;
  final DateTime? availableBy;
  final double? lat;
  final double? lng;
  final double? radiusKm; // 0.1 - 100, needs lat+lng or a city
  final String ordering; // newest | rent | -rent | distance

  const ListingFilters({
    this.query = '',
    this.cityId,
    this.roomType,
    this.minRent,
    this.maxRent,
    this.availableBy,
    this.lat,
    this.lng,
    this.radiusKm,
    this.ordering = 'newest',
  });

  bool get hasPoint => lat != null && lng != null;

  // Distance needs a center: the point (lat/lng) or the city center
  bool get hasCenter => hasPoint || cityId != null;

  // Number of filters set in the sheet (the text query is shown in the search box)
  int get activeCount {
    var count = 0;
    if (cityId != null) count++;
    if (roomType != null) count++;
    if (minRent != null || maxRent != null) count++;
    if (availableBy != null) count++;
    if (radiusKm != null && hasCenter) count++;
    if (ordering != 'newest') count++;
    return count;
  }

  bool get hasFilters => activeCount > 0 || hasPoint;

  // Use the sentinel default so nullable fields can be cleared, e.g. copyWith(cityId: null)
  ListingFilters copyWith({
    String? query,
    Object? cityId = _unset,
    Object? roomType = _unset,
    Object? minRent = _unset,
    Object? maxRent = _unset,
    Object? availableBy = _unset,
    Object? lat = _unset,
    Object? lng = _unset,
    Object? radiusKm = _unset,
    String? ordering,
  }) {
    return ListingFilters(
      query: query ?? this.query,
      cityId: identical(cityId, _unset) ? this.cityId : cityId as int?,
      roomType: identical(roomType, _unset) ? this.roomType : roomType as String?,
      minRent: identical(minRent, _unset) ? this.minRent : minRent as int?,
      maxRent: identical(maxRent, _unset) ? this.maxRent : maxRent as int?,
      availableBy: identical(availableBy, _unset) ? this.availableBy : availableBy as DateTime?,
      // num so that ints like copyWith(radiusKm: 5) work too
      lat: identical(lat, _unset) ? this.lat : (lat as num?)?.toDouble(),
      lng: identical(lng, _unset) ? this.lng : (lng as num?)?.toDouble(),
      radiusKm: identical(radiusKm, _unset) ? this.radiusKm : (radiusKm as num?)?.toDouble(),
      ordering: ordering ?? this.ordering,
    );
  }

  // Same filters without the sheet values (keeps the text query)
  ListingFilters cleared() => ListingFilters(query: query);

  // Query params for the backend. Empty values are left out, and distance
  // params are only sent when there is a center, otherwise the backend returns 400.
  Map<String, dynamic> toQueryParameters() {
    final q = query.trim();
    return {
      if (q.isNotEmpty) 'q': q,
      if (cityId != null) 'city': cityId,
      if (roomType != null) 'room_type': roomType,
      if (minRent != null) 'min_rent': minRent,
      if (maxRent != null) 'max_rent': maxRent,
      if (availableBy != null) 'available_by': formatDate(availableBy!),
      if (hasPoint) 'lat': lat,
      if (hasPoint) 'lng': lng,
      if (radiusKm != null && hasCenter) 'radius_km': radiusKm,
      if (ordering != 'newest' && (ordering != 'distance' || hasCenter)) 'ordering': ordering,
    };
  }

  static String formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListingFilters &&
          other.query == query &&
          other.cityId == cityId &&
          other.roomType == roomType &&
          other.minRent == minRent &&
          other.maxRent == maxRent &&
          other.availableBy == availableBy &&
          other.lat == lat &&
          other.lng == lng &&
          other.radiusKm == radiusKm &&
          other.ordering == ordering;

  @override
  int get hashCode => Object.hash(
        query,
        cityId,
        roomType,
        minRent,
        maxRent,
        availableBy,
        lat,
        lng,
        radiusKm,
        ordering,
      );
}

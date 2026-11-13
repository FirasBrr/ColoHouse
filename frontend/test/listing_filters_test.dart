import 'package:flutter_test/flutter_test.dart';
import 'package:front_colohouse/features/housing/models/listing_filters.dart';

void main() {
  group('ListingFilters', () {
    test('empty filters send no params', () {
      const f = ListingFilters();
      expect(f.toQueryParameters(), isEmpty);
      expect(f.activeCount, 0);
      expect(f.hasFilters, isFalse);
    });

    test('equal values are equal (Riverpod family key)', () {
      final a = ListingFilters(query: 'studio', cityId: 1, availableBy: DateTime(2026, 12, 1), radiusKm: 5);
      final b = ListingFilters(query: 'studio', cityId: 1, availableBy: DateTime(2026, 12, 1), radiusKm: 5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == b.copyWith(radiusKm: 6), isFalse);
    });

    test('copyWith keeps values unless told, and can clear them', () {
      const f = ListingFilters(cityId: 2, roomType: 'private', maxRent: 400);
      expect(f.copyWith(minRent: 100).cityId, 2);
      expect(f.copyWith(cityId: null).cityId, isNull);
      expect(f.copyWith(cityId: null).roomType, 'private');
      expect(f.cleared(), const ListingFilters());
    });

    test('toQueryParameters uses the backend names and omits empty values', () {
      final f = ListingFilters(
        query: '  studio ',
        cityId: 1,
        roomType: 'private',
        minRent: 200,
        maxRent: 500,
        availableBy: DateTime(2026, 12, 1),
        radiusKm: 5,
        ordering: 'distance',
      );
      expect(f.toQueryParameters(), {
        'q': 'studio',
        'city': 1,
        'room_type': 'private',
        'min_rent': 200,
        'max_rent': 500,
        'available_by': '2026-12-01',
        'radius_km': 5.0,
        'ordering': 'distance',
      });
      expect(f.activeCount, 6);
    });

    test('distance params are dropped without a center', () {
      const f = ListingFilters(radiusKm: 5, ordering: 'distance');
      expect(f.toQueryParameters(), isEmpty);
      const withPoint = ListingFilters(lat: 36.8, lng: 10.18, radiusKm: 5);
      expect(withPoint.toQueryParameters(), {'lat': 36.8, 'lng': 10.18, 'radius_km': 5.0});
    });

    test('newest is the default ordering and is not sent', () {
      expect(const ListingFilters(ordering: 'rent').toQueryParameters(), {'ordering': 'rent'});
      expect(const ListingFilters(ordering: 'newest').toQueryParameters(), isEmpty);
    });
  });
}

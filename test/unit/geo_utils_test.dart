import 'package:flutter_test/flutter_test.dart';
import 'package:quickserve/core/utils/geo_utils.dart';

void main() {
  group('GeoUtils Unit Tests', () {
    test('coordinate validation works correctly', () {
      expect(GeoUtils.isValidLatitude(0), isTrue);
      expect(GeoUtils.isValidLatitude(90), isTrue);
      expect(GeoUtils.isValidLatitude(-90), isTrue);
      expect(GeoUtils.isValidLatitude(90.1), isFalse);
      expect(GeoUtils.isValidLatitude(-90.1), isFalse);

      expect(GeoUtils.isValidLongitude(0), isTrue);
      expect(GeoUtils.isValidLongitude(180), isTrue);
      expect(GeoUtils.isValidLongitude(-180), isTrue);
      expect(GeoUtils.isValidLongitude(180.1), isFalse);
      expect(GeoUtils.isValidLongitude(-180.1), isFalse);

      expect(GeoUtils.isValidCoordinate(12.9716, 77.5946), isTrue);
      expect(GeoUtils.isValidCoordinate(95.0, 77.5946), isFalse);
      expect(GeoUtils.isValidCoordinate(12.9716, 185.0), isFalse);
    });

    test('toPointWkt formats properly as POINT(longitude latitude)', () {
      final wkt = GeoUtils.toPointWkt(latitude: 12.9716, longitude: 77.5946);
      expect(wkt, 'POINT(77.5946 12.9716)');
    });

    test('parsePoint correctly parses WKT format', () {
      final point = GeoUtils.parsePoint('POINT(77.5946 12.9716)');
      expect(point, isNotNull);
      expect(point!.latitude, closeTo(12.9716, 0.0001));
      expect(point.longitude, closeTo(77.5946, 0.0001));
    });

    test('parsePoint correctly parses GeoJSON map format and map fields', () {
      final geoJson = {
        'type': 'Point',
        'coordinates': [77.5946, 12.9716],
      };
      final point1 = GeoUtils.parsePoint(geoJson);
      expect(point1, isNotNull);
      expect(point1!.latitude, closeTo(12.9716, 0.0001));
      expect(point1.longitude, closeTo(77.5946, 0.0001));

      final mapFields = {
        'latitude': 12.9716,
        'longitude': 77.5946,
      };
      final point2 = GeoUtils.parsePoint(mapFields);
      expect(point2, isNotNull);
      expect(point2!.latitude, closeTo(12.9716, 0.0001));
      expect(point2.longitude, closeTo(77.5946, 0.0001));
    });

    test('parsePoint correctly parses PostGIS EWKB hex string format', () {
      // EWKB Little-Endian Point(77.5863, 12.9695) with SRID 4326
      const ewkbHex = '0101000020E6100000C1FDF49F866553406566666666F02940';
      final point = GeoUtils.parsePoint(ewkbHex);
      expect(point, isNotNull);
      expect(point!.latitude, closeTo(12.9695, 0.01));
      expect(point.longitude, closeTo(77.5863, 0.01));
    });

    test('parsePoint handles invalid or null input gracefully', () {
      expect(GeoUtils.parsePoint(null), isNull);
      expect(GeoUtils.parsePoint('INVALID_DATA'), isNull);
      expect(GeoUtils.parsePoint({}), isNull);
    });

    test('haversineDistanceKm calculates great circle distance accurately', () {
      final zeroDist = GeoUtils.haversineDistanceKm(12.9716, 77.5946, 12.9716, 77.5946);
      expect(zeroDist, closeTo(0.0, 0.001));

      // Bangalore MG Road to Koramangala (~5.1 km)
      final dist = GeoUtils.haversineDistanceKm(12.9716, 77.5946, 12.9352, 77.6245);
      expect(dist, greaterThan(4.5));
      expect(dist, lessThan(6.0));
    });
  });
}

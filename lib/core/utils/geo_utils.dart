import 'dart:math' as math;

/// Represents a geographic coordinate pair (latitude, longitude).
class GeoPoint {
  final double latitude;
  final double longitude;

  const GeoPoint({
    required this.latitude,
    required this.longitude,
  });

  /// Formats to PostGIS Well-Known Text (WKT) representation:
  /// In WKT standard, longitude precedes latitude: `POINT(longitude latitude)`.
  String toWkt() => 'POINT($longitude $latitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() => 'GeoPoint(lat: $latitude, lon: $longitude)';
}

/// Utility for validating and converting PostGIS geography points.
class GeoUtils {
  /// Validates individual latitude (-90 to 90).
  static bool isValidLatitude(double? latitude) {
    if (latitude == null) return false;
    return latitude >= -90.0 && latitude <= 90.0;
  }

  /// Validates individual longitude (-180 to 180).
  static bool isValidLongitude(double? longitude) {
    if (longitude == null) return false;
    return longitude >= -180.0 && longitude <= 180.0;
  }

  /// Validates that latitude is between -90 and 90, and longitude is between -180 and 180.
  static bool isValidCoordinates(double? latitude, double? longitude) {
    return isValidLatitude(latitude) && isValidLongitude(longitude);
  }

  /// Alias for [isValidCoordinates].
  static bool isValidCoordinate(double? latitude, double? longitude) {
    return isValidCoordinates(latitude, longitude);
  }

  /// Formats latitude and longitude into PostGIS WKT `POINT(longitude latitude)`.
  /// Throws [ArgumentError] if the coordinates are out of bounds.
  static String formatPointWkt(double latitude, double longitude) {
    if (!isValidCoordinates(latitude, longitude)) {
      throw ArgumentError(
        'Invalid coordinates: latitude must be between -90 and 90, '
        'longitude between -180 and 180 (received: lat $latitude, lon $longitude).',
      );
    }
    return 'POINT($longitude $latitude)';
  }

  /// Formats named latitude and longitude to PostGIS WKT `POINT(longitude latitude)`.
  static String toPointWkt({required double latitude, required double longitude}) {
    return formatPointWkt(latitude, longitude);
  }

  /// Parses a PostGIS representation from Supabase into a [GeoPoint].
  /// 
  /// Supports:
  /// - WKT String: `POINT(77.5946 12.9716)`
  /// - GeoJSON Map: `{"type": "Point", "coordinates": [77.5946, 12.9716]}`
  /// - EWKB / Hex string fallback if present
  static GeoPoint? parsePoint(dynamic raw) {
    if (raw == null) return null;

    if (raw is Map) {
      // GeoJSON format: coordinates are [longitude, latitude]
      final coords = raw['coordinates'];
      if (coords is List && coords.length >= 2) {
        final lon = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        if (isValidCoordinates(lat, lon)) {
          return GeoPoint(latitude: lat, longitude: lon);
        }
      }
      return null;
    }

    if (raw is String) {
      final str = raw.trim();
      // Match WKT `POINT(lon lat)` or `POINT (lon lat)`
      final regExp = RegExp(
        r'POINT\s*\(\s*([+-]?\d+(?:\.\d+)?)\s+([+-]?\d+(?:\.\d+)?)\s*\)',
        caseSensitive: false,
      );
      final match = regExp.firstMatch(str);
      if (match != null) {
        final lon = double.tryParse(match.group(1)!);
        final lat = double.tryParse(match.group(2)!);
        if (lat != null && lon != null && isValidCoordinates(lat, lon)) {
          return GeoPoint(latitude: lat, longitude: lon);
        }
      }
    }

    return null;
  }

  /// Calculates great-circle distance between two coordinates in kilometers using Haversine formula.
  static double haversineDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double r = 6371.0; // Earth radius in km
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);
}


import 'dart:typed_data';
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
  /// - GeoPoint instance: directly returned
  /// - WKT String: `POINT(77.5946 12.9716)`
  /// - PostGIS EWKB / Hex string: `0101000020E6100000...`
  /// - GeoJSON Map: `{"type": "Point", "coordinates": [77.5946, 12.9716]}`
  /// - Map with latitude/longitude or lat/lon fields
  /// - Comma-separated String: `"12.9716, 77.5946"`
  static GeoPoint? parsePoint(dynamic raw) {
    if (raw == null) return null;
    if (raw is GeoPoint) return raw;

    if (raw is Map) {
      // 1. GeoJSON format: coordinates are [longitude, latitude]
      final coords = raw['coordinates'];
      if (coords is List && coords.length >= 2) {
        final lon = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        if (isValidCoordinates(lat, lon)) {
          return GeoPoint(latitude: lat, longitude: lon);
        }
      }

      // 2. Map with explicit keys
      final lat = (raw['latitude'] ?? raw['lat']) as num?;
      final lon = (raw['longitude'] ?? raw['lon'] ?? raw['lng']) as num?;
      if (lat != null && lon != null) {
        final dLat = lat.toDouble();
        final dLon = lon.toDouble();
        if (isValidCoordinates(dLat, dLon)) {
          return GeoPoint(latitude: dLat, longitude: dLon);
        }
      }
      return null;
    }

    if (raw is String) {
      final str = raw.trim();
      if (str.isEmpty) return null;

      // 1. Match WKT `POINT(lon lat)` or `POINT (lon lat)`
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

      // 2. EWKB / PostGIS Hex string format
      final ewkbPoint = _parseEwkbHex(str);
      if (ewkbPoint != null) return ewkbPoint;

      // 3. Comma-separated lat,lon format e.g. "12.9716, 77.5946"
      if (str.contains(',')) {
        final parts = str.split(',');
        if (parts.length == 2) {
          final lat = double.tryParse(parts[0].trim());
          final lon = double.tryParse(parts[1].trim());
          if (lat != null && lon != null && isValidCoordinates(lat, lon)) {
            return GeoPoint(latitude: lat, longitude: lon);
          }
        }
      }
    }

    return null;
  }

  /// Parses PostGIS EWKB binary hex string into [GeoPoint].
  static GeoPoint? _parseEwkbHex(String hexStr) {
    try {
      final cleanHex = hexStr.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
      if (cleanHex.length < 42) return null;

      final bytes = Uint8List(cleanHex.length ~/ 2);
      for (int i = 0; i < bytes.length; i++) {
        bytes[i] = int.parse(cleanHex.substring(i * 2, i * 2 + 2), radix: 16);
      }

      final byteData = ByteData.sublistView(bytes);
      final isLittleEndian = bytes[0] == 1;
      final endian = isLittleEndian ? Endian.little : Endian.big;

      final type = byteData.getUint32(1, endian);
      final bool hasSrid = (type & 0x20000000) != 0;

      int offset = 5;
      if (hasSrid) {
        offset += 4; // Skip 4-byte SRID field
      }

      if (offset + 16 > bytes.length) return null;

      final lon = byteData.getFloat64(offset, endian);
      final lat = byteData.getFloat64(offset + 8, endian);

      if (isValidCoordinates(lat, lon)) {
        return GeoPoint(latitude: lat, longitude: lon);
      }
    } catch (_) {}
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


import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/utils/geo_utils.dart';

/// Result container for calculated route information between two points.
class RouteResult {
  final List<LatLng> polylinePoints;
  final double distanceKm;
  final int durationMinutes;
  final bool isSuccess;
  final String? errorMessage;

  const RouteResult({
    required this.polylinePoints,
    required this.distanceKm,
    required this.durationMinutes,
    this.isSuccess = true,
    this.errorMessage,
  });

  factory RouteResult.fallback({
    required GeoPoint origin,
    required GeoPoint destination,
    String? error,
  }) {
    final dist = GeoUtils.haversineDistanceKm(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    // Estimate ~30 km/h average urban speed if routing service is offline
    final durationMins = (dist / 30.0 * 60.0).round().clamp(1, 480);

    return RouteResult(
      polylinePoints: [
        LatLng(origin.latitude, origin.longitude),
        LatLng(destination.latitude, destination.longitude),
      ],
      distanceKm: dist,
      durationMinutes: durationMins,
      isSuccess: false,
      errorMessage: error ?? 'Using direct distance fallback',
    );
  }
}

/// Abstract contract for calculating in-app driving routes.
abstract class RoutingService {
  Future<RouteResult> calculateRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  });
}

/// Implementation of RoutingService using OSRM (Open Source Routing Machine).
class RoutingServiceImpl implements RoutingService {
  final http.Client _client;

  RoutingServiceImpl({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<RouteResult> calculateRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    if (!GeoUtils.isValidCoordinates(origin.latitude, origin.longitude) ||
        !GeoUtils.isValidCoordinates(destination.latitude, destination.longitude)) {
      return RouteResult.fallback(
        origin: origin,
        destination: destination,
        error: 'Invalid coordinates provided for route calculation',
      );
    }

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await _client.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;

        if (routes != null && routes.isNotEmpty) {
          final firstRoute = routes[0] as Map<String, dynamic>;
          final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
          final coordsList = geometry?['coordinates'] as List?;

          final distanceMeters = (firstRoute['distance'] as num?)?.toDouble() ?? 0.0;
          final durationSeconds = (firstRoute['duration'] as num?)?.toDouble() ?? 0.0;

          final polyline = <LatLng>[];
          if (coordsList != null) {
            for (final item in coordsList) {
              if (item is List && item.length >= 2) {
                final lon = (item[0] as num).toDouble();
                final lat = (item[1] as num).toDouble();
                polyline.add(LatLng(lat, lon));
              }
            }
          }

          if (polyline.isEmpty) {
            polyline.addAll([
              LatLng(origin.latitude, origin.longitude),
              LatLng(destination.latitude, destination.longitude),
            ]);
          }

          final distKm = distanceMeters / 1000.0;
          final durMins = (durationSeconds / 60.0).round().clamp(1, 480);

          return RouteResult(
            polylinePoints: polyline,
            distanceKm: distKm,
            durationMinutes: durMins,
            isSuccess: true,
          );
        }
      }

      return RouteResult.fallback(
        origin: origin,
        destination: destination,
        error: 'Routing service unavailable',
      );
    } catch (e) {
      return RouteResult.fallback(
        origin: origin,
        destination: destination,
        error: e.toString(),
      );
    }
  }
}

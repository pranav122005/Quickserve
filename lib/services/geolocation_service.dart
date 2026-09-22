import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../core/utils/geo_utils.dart';

/// Status of device location services and runtime permissions.
enum LocationPermissionStatus {
  serviceDisabled,
  denied,
  permanentlyDenied,
  granted,
}

/// Position data provided by GeolocationService.
class GeoPosition {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  const GeoPosition({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  GeoPoint toGeoPoint() => GeoPoint(latitude: latitude, longitude: longitude);
}

/// Abstract contract for device/browser geolocation.
abstract class GeolocationService {
  /// Checks if the device location services (GPS) are turned on.
  Future<bool> isLocationServiceEnabled();

  /// Checks the current location permission without prompting the user.
  Future<LocationPermissionStatus> checkPermission();

  /// Prompts the user to grant location permission on-demand.
  Future<LocationPermissionStatus> requestPermission();

  /// Opens system location settings (when GPS is disabled).
  Future<bool> openLocationSettings();

  /// Opens application settings (when permission was permanently denied).
  Future<bool> openAppSettings();

  /// Fetches the single current geographic position using real device/browser GPS.
  /// NEVER generates simulated or placeholder coordinates in production.
  Future<GeoPosition?> getCurrentPosition();

  /// Starts a real-time position stream with distance and time throttling.
  Stream<GeoPosition> watchPosition({
    Duration interval = const Duration(seconds: 10),
    int distanceFilterMeters = 20,
  });
}

/// Production implementation of GeolocationService using Geolocator.
class GeolocationServiceImpl implements GeolocationService {
  @override
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionStatus.serviceDisabled;
    }
    final permission = await Geolocator.checkPermission();
    return _mapPermission(permission);
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionStatus.serviceDisabled;
    }
    final permission = await Geolocator.requestPermission();
    return _mapPermission(permission);
  }

  LocationPermissionStatus _mapPermission(LocationPermission p) {
    switch (p) {
      case LocationPermission.denied:
        return LocationPermissionStatus.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.permanentlyDenied;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return LocationPermissionStatus.granted;
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.denied;
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  @override
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  @override
  Future<GeoPosition?> getCurrentPosition() async {
    final status = await checkPermission();
    if (status != LocationPermissionStatus.granted) {
      return null;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!GeoUtils.isValidCoordinates(pos.latitude, pos.longitude)) {
        return null;
      }

      return GeoPosition(
        latitude: pos.latitude,
        longitude: pos.longitude,
        timestamp: pos.timestamp,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<GeoPosition> watchPosition({
    Duration interval = const Duration(seconds: 10),
    int distanceFilterMeters = 20,
  }) {
    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters,
    );

    return Geolocator.getPositionStream(locationSettings: settings)
        .where((pos) => GeoUtils.isValidCoordinates(pos.latitude, pos.longitude))
        .map((pos) => GeoPosition(
              latitude: pos.latitude,
              longitude: pos.longitude,
              timestamp: pos.timestamp,
            ));
  }
}

import 'package:url_launcher/url_launcher.dart';
import 'geo_utils.dart';
import '../errors/app_exception.dart';

/// Helper utility for launching external maps and navigation applications.
class NavigationUtils {
  /// Opens external maps application targeting customer coordinates [location] or fallback [address].
  static Future<void> launchDirections({
    required GeoPoint? location,
    String? address,
  }) async {
    final bool hasValidCoords = location != null &&
        GeoUtils.isValidLatitude(location.latitude) &&
        GeoUtils.isValidLongitude(location.longitude);
    final cleanAddress = address?.trim();
    final bool hasValidAddress = cleanAddress != null &&
        cleanAddress.isNotEmpty &&
        cleanAddress != 'Address not specified';

    if (!hasValidCoords && !hasValidAddress) {
      throw const ServiceException('Customer location is unavailable.');
    }

    Uri primaryUri;
    Uri webMapsUri;

    if (hasValidCoords) {
      final lat = location.latitude;
      final lng = location.longitude;
      primaryUri = Uri.parse('google.navigation:q=$lat,$lng');
      webMapsUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
    } else {
      final encoded = Uri.encodeComponent(cleanAddress!);
      primaryUri = Uri.parse('geo:0,0?q=$encoded');
      webMapsUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encoded',
      );
    }

    try {
      if (await canLaunchUrl(primaryUri)) {
        final launched = await launchUrl(primaryUri);
        if (launched) return;
      }

      if (await canLaunchUrl(webMapsUri)) {
        final launched = await launchUrl(webMapsUri, mode: LaunchMode.externalApplication);
        if (launched) return;
      }

      throw const ServiceException('Unable to open external maps application on this device.');
    } catch (e) {
      if (e is ServiceException) rethrow;
      throw ServiceException('Failed to launch directions: ${e.toString()}');
    }
  }
}

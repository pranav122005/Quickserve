import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../utils/geo_utils.dart';
import '../../repositories/repository_providers.dart';

/// Reusable Interactive Single In-App Route Map Card for QuickServe.
/// Displays Customer location, Agent location, polyline route, distance, travel duration,
/// and in-app navigation controls without opening external maps.
class InAppRouteMapCard extends ConsumerStatefulWidget {
  final GeoPoint? customerLocation;
  final String customerAddress;
  final GeoPoint? agentLocation;
  final String? agentName;
  final double height;
  final bool showHeaderControls;
  final bool showDirectionsButton;

  const InAppRouteMapCard({
    super.key,
    required this.customerLocation,
    required this.customerAddress,
    this.agentLocation,
    this.agentName,
    this.height = 300,
    this.showHeaderControls = true,
    this.showDirectionsButton = true,
  });

  @override
  ConsumerState<InAppRouteMapCard> createState() => _InAppRouteMapCardState();
}

class _InAppRouteMapCardState extends ConsumerState<InAppRouteMapCard> {
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  double? _distanceKm;
  int? _durationMins;
  bool _isCalculatingRoute = false;
  bool _isRouteCalculated = false;
  String? _statusMessage;
  String? _routingErrorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  @override
  void didUpdateWidget(covariant InAppRouteMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.agentLocation != widget.agentLocation ||
        oldWidget.customerLocation != widget.customerLocation) {
      _fetchRoute();
    }
  }

  Future<void> _fetchRoute() async {
    final custLoc = widget.customerLocation;
    final agtLoc = widget.agentLocation;

    if (custLoc == null ||
        !GeoUtils.isValidLatitude(custLoc.latitude) ||
        !GeoUtils.isValidLongitude(custLoc.longitude)) {
      if (mounted) {
        setState(() {
          _routePoints = [];
          _distanceKm = null;
          _durationMins = null;
          _statusMessage = 'Customer location coordinates unavailable.';
          _routingErrorMessage = null;
          _isRouteCalculated = false;
        });
      }
      return;
    }

    if (agtLoc == null ||
        !GeoUtils.isValidLatitude(agtLoc.latitude) ||
        !GeoUtils.isValidLongitude(agtLoc.longitude)) {
      // Customer location only
      if (mounted) {
        setState(() {
          _routePoints = [LatLng(custLoc.latitude, custLoc.longitude)];
          _distanceKm = null;
          _durationMins = null;
          _statusMessage = null;
          _routingErrorMessage = null;
          _isRouteCalculated = false;
        });
        _recenterMap();
      }
      return;
    }

    setState(() {
      _isCalculatingRoute = true;
      _statusMessage = null;
      _routingErrorMessage = null;
    });

    try {
      final routingService = ref.read(routingServiceProvider);
      final result = await routingService.calculateRoute(
        origin: agtLoc,
        destination: custLoc,
      );

      if (mounted) {
        setState(() {
          _routePoints = result.polylinePoints;
          _distanceKm = result.distanceKm;
          _durationMins = result.durationMinutes;
          _isCalculatingRoute = false;
          _isRouteCalculated = true;
        });
        _recenterMap();
      }
    } catch (_) {
      if (mounted) {
        final fallbackDist = GeoUtils.haversineDistanceKm(
          agtLoc.latitude,
          agtLoc.longitude,
          custLoc.latitude,
          custLoc.longitude,
        );
        setState(() {
          _routePoints = [
            LatLng(agtLoc.latitude, agtLoc.longitude),
            LatLng(custLoc.latitude, custLoc.longitude),
          ];
          _distanceKm = fallbackDist;
          _durationMins = (fallbackDist / 30.0 * 60.0).round().clamp(1, 480);
          _isCalculatingRoute = false;
          _isRouteCalculated = true;
          _routingErrorMessage = 'Unable to calculate the route right now.';
        });
        _recenterMap();
      }
    }
  }

  void _recenterMap() {
    final custLoc = widget.customerLocation;
    final agtLoc = widget.agentLocation;

    if (custLoc == null) return;

    if (agtLoc != null &&
        GeoUtils.isValidLatitude(agtLoc.latitude) &&
        GeoUtils.isValidLongitude(agtLoc.longitude)) {
      final bounds = LatLngBounds(
        LatLng(
          custLoc.latitude < agtLoc.latitude ? custLoc.latitude : agtLoc.latitude,
          custLoc.longitude < agtLoc.longitude ? custLoc.longitude : agtLoc.longitude,
        ),
        LatLng(
          custLoc.latitude > agtLoc.latitude ? custLoc.latitude : agtLoc.latitude,
          custLoc.longitude > agtLoc.longitude ? custLoc.longitude : agtLoc.longitude,
        ),
      );

      try {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(48),
          ),
        );
      } catch (_) {
        _mapController.move(LatLng(custLoc.latitude, custLoc.longitude), 13.5);
      }
    } else {
      try {
        _mapController.move(LatLng(custLoc.latitude, custLoc.longitude), 14.5);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final custLoc = widget.customerLocation;
    final agtLoc = widget.agentLocation;

    final hasCustCoords = custLoc != null &&
        GeoUtils.isValidLatitude(custLoc.latitude) &&
        GeoUtils.isValidLongitude(custLoc.longitude);

    final initialCenter = hasCustCoords
        ? LatLng(custLoc.latitude, custLoc.longitude)
        : const LatLng(12.9716, 77.5946);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          if (widget.showHeaderControls)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.map_rounded, size: 18, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      const Text(
                        'IN-APP LIVE ROUTE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: _isCalculatingRoute ? null : _fetchRoute,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: _isCalculatingRoute
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF475569)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: _recenterMap,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.customerAddress.isNotEmpty
                        ? widget.customerAddress
                        : 'Service Address',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

          // Single Interactive Map Canvas
          SizedBox(
            height: widget.height,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: 14.0,
                    minZoom: 3.0,
                    maxZoom: 18.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.quickserve.app',
                    ),

                    // Route Polyline
                    if (_routePoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 5.0,
                            color: const Color(0xFF2563EB),
                          ),
                        ],
                      ),

                    // Markers Layer
                    MarkerLayer(
                      markers: [
                        // Customer Marker
                        if (hasCustCoords)
                          Marker(
                            point: LatLng(custLoc.latitude, custLoc.longitude),
                            width: 44,
                            height: 44,
                            child: Tooltip(
                              message: 'Customer Location\n${widget.customerAddress}',
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ),

                        // Agent Marker
                        if (agtLoc != null &&
                            GeoUtils.isValidLatitude(agtLoc.latitude) &&
                            GeoUtils.isValidLongitude(agtLoc.longitude))
                          Marker(
                            point: LatLng(agtLoc.latitude, agtLoc.longitude),
                            width: 44,
                            height: 44,
                            child: Tooltip(
                              message: widget.agentName != null
                                  ? 'Service Agent (${widget.agentName})'
                                  : 'Service Agent Location',
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Floating Recenter Overlay Button inside Map
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'recenter_map_fab',
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2563EB),
                    elevation: 3,
                    onPressed: _recenterMap,
                    child: const Icon(Icons.my_location_rounded, size: 20),
                  ),
                ),

                // Notice Banner if customer coordinates missing
                if (!hasCustCoords)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber.shade800),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _statusMessage ?? 'Customer location coordinates unavailable.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Footer Bar: Distance, Travel Time, & Get Directions Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_routingErrorMessage != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _routingErrorMessage!,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.amber.shade900),
                          ),
                        ),
                        TextButton(
                          onPressed: _fetchRoute,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Try Again', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],

                Row(
                  children: [
                    // Distance & Travel Time display
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.near_me_rounded, size: 16, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              Text(
                                _distanceKm != null
                                    ? '${_distanceKm!.toStringAsFixed(1)} km'
                                    : 'Distance: --',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if (_durationMins != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: Text(
                                    '~$_durationMins min',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF047857),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Live in-app road routing',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),

                    // Get Directions / Route Calculated Button
                    if (widget.showDirectionsButton)
                      ElevatedButton.icon(
                        icon: _isCalculatingRoute
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(
                                _isRouteCalculated ? Icons.check_circle_rounded : Icons.navigation_rounded,
                                size: 18,
                              ),
                        label: Text(
                          _isCalculatingRoute
                              ? 'Calculating...'
                              : (_isRouteCalculated ? 'Route Calculated ✓' : 'Get Directions'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRouteCalculated ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: _isCalculatingRoute
                            ? null
                            : () {
                                _fetchRoute();
                              },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

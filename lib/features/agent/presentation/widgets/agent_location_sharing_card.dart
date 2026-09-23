import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../services/geolocation_service.dart';
import '../controllers/agent_location_controller.dart';

class AgentLocationSharingCard extends ConsumerStatefulWidget {
  final String agentId;

  const AgentLocationSharingCard({super.key, required this.agentId});

  @override
  ConsumerState<AgentLocationSharingCard> createState() => _AgentLocationSharingCardState();
}

class _AgentLocationSharingCardState extends ConsumerState<AgentLocationSharingCard> {
  final MapController _mapController = MapController();
  bool _isDetectingGps = false;

  Future<void> _detectLiveGpsLocation(WidgetRef ref) async {
    setState(() => _isDetectingGps = true);
    try {
      final geoService = ref.read(geolocationServiceProvider);
      final perm = await geoService.requestPermission();

      if (perm == LocationPermissionStatus.granted) {
        final position = await geoService.getCurrentPosition();
        if (position != null) {
          ref.read(agentLocationControllerProvider.notifier).updateLocationManually(
                agentId: widget.agentId,
                latitude: position.latitude,
                longitude: position.longitude,
              );

          _mapController.move(LatLng(position.latitude, position.longitude), 14.0);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Live GPS location updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to detect GPS.'),
            backgroundColor: Colors.amber,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPS error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDetectingGps = false);
    }
  }

  void _showMapPickerModal(BuildContext context, WidgetRef ref, double currentLat, double currentLon) {
    LatLng selectedPos = LatLng(currentLat, currentLon);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.map, color: Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Select Live Station on Map',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(currentLat, currentLon),
                    initialZoom: 14.0,
                    onTap: (tapPosition, point) {
                      setModalState(() {
                        selectedPos = point;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.quickserve.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: selectedPos,
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 44,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Confirm Position'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          ref
                              .read(agentLocationControllerProvider.notifier)
                              .updateLocationManually(
                                agentId: widget.agentId,
                                latitude: selectedPos.latitude,
                                longitude: selectedPos.longitude,
                              );
                          _mapController.move(selectedPos, 14.0);
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locState = ref.watch(agentLocationControllerProvider);

    final double activeLat = locState.latitude ?? 12.9716;
    final double activeLon = locState.longitude != 0.0 ? locState.longitude : 77.5946;
    final LatLng centerPoint = LatLng(activeLat, activeLon);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.my_location, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Live Service Location & Map',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: locState.isPublishing ? Colors.green.shade50 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: locState.isPublishing ? Colors.green.shade300 : Colors.grey.shade400,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: locState.isPublishing ? Colors.green : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  locState.isPublishing ? 'Live Signals ON' : 'Station Ready',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: locState.isPublishing ? Colors.green.shade800 : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Base Station Address: Central Hub Service Coverage',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Embedded Live Map Preview Box
          Container(
            height: 180,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: centerPoint,
                      initialZoom: 13.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.quickserve.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: centerPoint,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 24),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Interactive OpenStreetMap',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Toolbar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: _isDetectingGps
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 16, color: Color(0xFF2563EB)),
                    label: Text(_isDetectingGps ? 'Detecting...' : 'Detect Live GPS'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: _isDetectingGps ? null : () => _detectLiveGpsLocation(ref),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.map_outlined, size: 16),
                    label: const Text('Select on Map'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _showMapPickerModal(context, ref, activeLat, activeLon),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

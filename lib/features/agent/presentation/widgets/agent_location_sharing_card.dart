import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/formatters.dart';
import '../controllers/agent_location_controller.dart';

class AgentLocationSharingCard extends ConsumerWidget {
  final String agentId;

  const AgentLocationSharingCard({super.key, required this.agentId});

  void _showCoordinateDialog(BuildContext context, WidgetRef ref) {
    final latController = TextEditingController(text: '12.9716');
    final lonController = TextEditingController(text: '77.5946');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Broadcast Agent Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Set simulated coordinates for testing live customer tracking.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: latController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Latitude (-90 to 90)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lonController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Longitude (-180 to 180)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final lat = double.tryParse(latController.text.trim());
              final lon = double.tryParse(lonController.text.trim());
              if (lat != null && lon != null) {
                ref
                    .read(agentLocationControllerProvider.notifier)
                    .updateLocationManually(
                      agentId: agentId,
                      latitude: lat,
                      longitude: lon,
                    );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Transmitted position: ($lat, $lon)')),
                );
              }
            },
            child: const Text('Transmit Position'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locState = ref.watch(agentLocationControllerProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: locState.isPublishing ? Colors.teal.shade300 : Colors.grey.shade300,
        ),
      ),
      color: locState.isPublishing ? Colors.teal.shade50.withValues(alpha: 0.3) : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: locState.isPublishing ? Colors.teal.shade100 : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_on,
                color: locState.isPublishing ? Colors.teal.shade800 : Colors.grey.shade600,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        locState.isPublishing
                            ? 'Location Sharing Active'
                            : 'Location Sharing Idle',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: locState.isPublishing ? Colors.teal.shade900 : Colors.grey.shade800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: locState.isPublishing ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    locState.latitude != null
                        ? 'Lat: ${locState.latitude!.toStringAsFixed(4)}, Lon: ${locState.longitude.toStringAsFixed(4)} • ${locState.lastPublishedAt != null ? Formatters.formatDateTime(locState.lastPublishedAt) : ""}'
                        : 'Transmits automatically during active accepted service.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_location_alt, size: 16),
              label: const Text('Update Position', style: TextStyle(fontSize: 12)),
              onPressed: () => _showCoordinateDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../../core/widgets/priority_badge.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../models/agent_location.dart';
import '../../../../models/service_assignment.dart';
import '../../../../models/service_request.dart';
import '../../../../repositories/repository_providers.dart';

/// Interactive live tracking screen for customers.
/// Shows real-time request lifecycle state, assigned agent location, and map.
class CustomerTrackingScreen extends ConsumerStatefulWidget {
  final String requestId;
  final ServiceRequest? initialRequest;

  const CustomerTrackingScreen({
    super.key,
    required this.requestId,
    this.initialRequest,
  });

  @override
  ConsumerState<CustomerTrackingScreen> createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends ConsumerState<CustomerTrackingScreen> {
  final MapController _mapController = MapController();
  late ServiceRequest _request;
  ServiceAssignment? _assignment;
  AgentLocation? _agentLocation;

  bool _isLoading = true;
  bool _isDispatching = false;
  bool _isCancelling = false;
  String? _errorMessage;

  RealtimeChannel? _requestChannel;
  RealtimeChannel? _assignmentChannel;
  RealtimeChannel? _locationChannel;
  Timer? _staleCheckTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialRequest != null) {
      _request = widget.initialRequest!;
    } else {
      _request = ServiceRequest(
        id: widget.requestId,
        customerId: '',
        category: '',
        title: 'Service Request',
        serviceAddress: '',
        priority: RequestPriority.normal,
        status: RequestStatus.pending,
      );
    }

    _initTracking();

    // Periodic timer to refresh freshness UI every 15 seconds
    _staleCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _agentLocation != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _staleCheckTimer?.cancel();
    final realtime = ref.read(realtimeServiceProvider);
    realtime.unsubscribe(_requestChannel);
    realtime.unsubscribe(_assignmentChannel);
    realtime.unsubscribe(_locationChannel);
    super.dispose();
  }

  Future<void> _initTracking() async {
    setState(() => _isLoading = true);
    await _loadLatestData();
    _setupRealtimeSubscriptions();
  }

  Future<void> _loadLatestData() async {
    try {
      final reqRepo = ref.read(serviceRequestRepositoryProvider);
      final assignRepo = ref.read(assignmentRepositoryProvider);
      final locRepo = ref.read(agentLocationRepositoryProvider);

      final req = await reqRepo.getRequestById(widget.requestId);
      final assign = await assignRepo.getAssignmentForRequest(widget.requestId);

      AgentLocation? loc;
      if (assign != null &&
          assign.status.isAccepted &&
          (req.status.isAssigned || req.status.isInProgress)) {
        loc = await locRepo.getAgentLocation(assign.agentId);
      }

      if (mounted) {
        setState(() {
          _request = req;
          _assignment = assign;
          _agentLocation = loc;
          _isLoading = false;
          _errorMessage = null;
        });

        _fitBoundsIfReady();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not sync request: $e';
        });
      }
    }
  }

  void _setupRealtimeSubscriptions() {
    final realtime = ref.read(realtimeServiceProvider);

    // 1. Listen for request updates
    _requestChannel = realtime.subscribeToRequest(
      requestId: widget.requestId,
      onUpdate: (updatedReq) {
        if (!mounted) return;
        setState(() {
          _request = updatedReq;
          // Location privacy: stop listening and clear location when request finishes or cancels
          if (updatedReq.status.isCompleted || updatedReq.status.isCancelled) {
            _agentLocation = null;
            if (_locationChannel != null) {
              realtime.unsubscribe(_locationChannel);
              _locationChannel = null;
            }
          }
        });
        _fitBoundsIfReady();
      },
    );

    // 2. Listen for assignment updates
    _assignmentChannel = realtime.subscribeToAssignment(
      requestId: widget.requestId,
      onUpdate: (updatedAssign) {
        if (!mounted) return;
        setState(() => _assignment = updatedAssign);

        if (updatedAssign.status.isAccepted &&
            (_request.status.isAssigned || _request.status.isInProgress)) {
          _listenToAgentLocation(updatedAssign.agentId);
        } else if (!updatedAssign.status.isAccepted) {
          setState(() => _agentLocation = null);
          if (_locationChannel != null) {
            realtime.unsubscribe(_locationChannel);
            _locationChannel = null;
          }
        }
      },
    );

    // If initial assignment was already accepted and request is active, subscribe to location
    if (_assignment != null &&
        _assignment!.status.isAccepted &&
        (_request.status.isAssigned || _request.status.isInProgress)) {
      _listenToAgentLocation(_assignment!.agentId);
    }
  }

  void _listenToAgentLocation(String agentId) {
    final realtime = ref.read(realtimeServiceProvider);
    if (_locationChannel != null) {
      realtime.unsubscribe(_locationChannel);
      _locationChannel = null;
    }

    _locationChannel = realtime.subscribeToAgentLocation(
      agentId: agentId,
      onLocationUpdate: (newLoc) {
        if (!mounted) return;
        setState(() => _agentLocation = newLoc);
        _fitBoundsIfReady();
      },
    );
  }

  void _fitBoundsIfReady() {
    final reqLoc = _request.location;
    final agtLoc = _agentLocation?.location;

    if (reqLoc != null && agtLoc != null && _assignment?.status.isAccepted == true) {
      try {
        final bounds = LatLngBounds.fromPoints([
          LatLng(reqLoc.latitude, reqLoc.longitude),
          LatLng(agtLoc.latitude, agtLoc.longitude),
        ]);
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
        );
      } catch (_) {}
    } else if (reqLoc != null) {
      try {
        _mapController.move(
          LatLng(reqLoc.latitude, reqLoc.longitude),
          14.0,
        );
      } catch (_) {}
    }
  }

  Future<void> _triggerDispatch() async {
    setState(() => _isDispatching = true);
    try {
      final dispatchService = ref.read(dispatchServiceProvider);
      final result = await dispatchService.dispatchRequest(_request.id);

      if (mounted) {
        if (result.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.isOffered
                    ? 'Dispatch successful! Offer dispatched to agent.'
                    : 'Dispatch requested: ${result.message}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dispatch response: ${result.message}'),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        }
        await _loadLatestData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dispatch failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDispatching = false);
      }
    }
  }

  Future<void> _cancelRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text(
          'Are you sure you want to cancel this service request? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Request'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCancelling = true);
    try {
      final repo = ref.read(serviceRequestRepositoryProvider);
      await repo.cancelRequest(_request.id);
      await _loadLatestData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service request has been cancelled.'),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  bool get _isAgentAccepted =>
      (_assignment != null && _assignment!.status.isAccepted) ||
      _request.status.isAssigned ||
      _request.status.isInProgress ||
      _request.status.isCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasReqLoc = _request.location != null;
    final initialCenter = hasReqLoc
        ? LatLng(_request.location!.latitude, _request.location!.longitude)
        : const LatLng(12.9716, 77.5946); // Default fallback center (Bangalore)

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.receipt_long_outlined, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _request.title.isNotEmpty
                    ? '${_request.formattedId} • ${_request.title}'
                    : 'Order Tracker',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh tracking data',
            onPressed: _isLoading ? null : _loadLatestData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading && _request.title == 'Service Request'
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Flipkart/Swiggy-Style Order Status Stepper
                _buildFlipkartStatusStepper(theme),

                // Conditional View: Searching View vs Interactive Map
                Expanded(
                  child: !_isAgentAccepted
                      ? _buildSearchingAgentView(theme)
                      : Stack(
                          children: [
                            // OpenStreetMap View (Only visible once agent accepts!)
                            FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: initialCenter,
                                initialZoom: 14.0,
                                minZoom: 4.0,
                                maxZoom: 18.0,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.quickserve.app',
                                ),
                                MarkerLayer(
                                  markers: _buildMapMarkers(),
                                ),
                              ],
                            ),

                            // Error banner if any
                            if (_errorMessage != null)
                              Positioned(
                                top: 16,
                                left: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Missing coordinates warning banner
                            if (!hasReqLoc)
                              Positioned(
                                top: 16,
                                left: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.shade300),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.amber.shade900),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'No GPS coordinates saved for this request. Address: ${_request.serviceAddress}',
                                          style: TextStyle(
                                            color: Colors.amber.shade900,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Bottom Floating Status Card
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 16,
                              child: _buildTrackingBottomCard(theme),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  /// Flipkart/Swiggy-Style Order Progress Stepper Header
  Widget _buildFlipkartStatusStepper(ThemeData theme) {
    int currentStep = 1;
    if (_request.status.isCompleted) {
      currentStep = 5;
    } else if (_request.status.isInProgress) {
      currentStep = 4;
    } else if (_request.status.isAssigned || (_assignment != null && _assignment!.status.isAccepted)) {
      currentStep = 3;
    } else if (_request.status.isPending || _request.status.isDispatching) {
      currentStep = 2;
    }

    final isCancelled = _request.status.isCancelled;

    final steps = [
      {'title': 'Placed', 'icon': Icons.assignment_turned_in},
      {'title': 'Matching', 'icon': Icons.radar},
      {'title': 'Assigned', 'icon': Icons.person_pin_circle},
      {'title': 'In Progress', 'icon': Icons.engineering},
      {'title': 'Completed', 'icon': Icons.check_circle},
    ];

    return Container(
      width: double.infinity,
      color: isCancelled ? Colors.red.shade50 : Colors.indigo.shade50.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          Row(
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                // Connecting Line
                final stepIdx = (index - 1) ~/ 2 + 1;
                final isPassed = currentStep > stepIdx;
                return Expanded(
                  child: Container(
                    height: 3,
                    color: isCancelled
                        ? Colors.red.shade200
                        : (isPassed ? Colors.green : Colors.grey.shade300),
                  ),
                );
              }

              final stepIdx = index ~/ 2 + 1;
              final isDone = currentStep > stepIdx;
              final isCurrent = currentStep == stepIdx;

              Color stepColor;
              if (isCancelled) {
                stepColor = Colors.red;
              } else if (isDone) {
                stepColor = Colors.green;
              } else if (isCurrent) {
                stepColor = Colors.indigo;
              } else {
                stepColor = Colors.grey.shade400;
              }

              return Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDone || isCurrent ? stepColor : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: stepColor, width: 2),
                    ),
                    child: Icon(
                      steps[stepIdx - 1]['icon'] as IconData,
                      size: 16,
                      color: isDone || isCurrent ? Colors.white : stepColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steps[stepIdx - 1]['title'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent ? stepColor : Colors.grey.shade700,
                    ),
                  ),
                ],
              );
            }),
          ),
          if (isCancelled) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Request Cancelled',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Flipkart/Swiggy-Style Searching for Agent Screen (Shown BEFORE agent accepts)
  Widget _buildSearchingAgentView(ThemeData theme) {
    final isCancelled = _request.status.isCancelled;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          // Animated Pulse Icon Container
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCancelled
                      ? Colors.red.shade50
                      : Colors.indigo.shade50,
                ),
              ),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCancelled
                      ? Colors.red.shade100
                      : Colors.indigo.shade100,
                ),
              ),
              CircleAvatar(
                radius: 32,
                backgroundColor: isCancelled ? Colors.red : const Color(0xFF2563EB),
                child: Icon(
                  isCancelled
                      ? Icons.cancel
                      : Icons.radar,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            isCancelled
                ? 'Request Was Cancelled'
                : 'Searching for Nearby Service Agent...',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isCancelled
                ? 'This service request was cancelled. You can create a new request at any time.'
                : 'We are notifying verified service experts near ${_request.serviceAddress}. The map will open automatically as soon as an agent accepts!',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Order Details Summary Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.handyman, color: Colors.indigo, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _request.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'Category: ${_request.category}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      PriorityBadge(priority: _request.priority),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _request.serviceAddress,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Action Buttons
          if (!isCancelled) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_request.status.canBeCancelledByCustomer)
                  OutlinedButton.icon(
                    onPressed: _isCancelling ? null : _cancelRequest,
                    icon: _isCancelling
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel Request'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isDispatching ? null : _triggerDispatch,
                  icon: _isDispatching
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.radar, size: 18),
                  label: const Text('Retry Dispatch'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Marker> _buildMapMarkers() {
    final markers = <Marker>[];

    // Customer / Service Location Marker
    if (_request.location != null) {
      markers.add(
        Marker(
          point: LatLng(_request.location!.latitude, _request.location!.longitude),
          width: 50,
          height: 50,
          child: Tooltip(
            message: 'Service Location\n${_request.serviceAddress}',
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                    ],
                  ),
                  child: const Icon(Icons.home, color: Colors.white, size: 18),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Assigned Agent Marker
    if (_agentLocation != null && _assignment?.status.isAccepted == true) {
      final isStale = _agentLocation!.isStale(thresholdSeconds: 120);
      markers.add(
        Marker(
          point: LatLng(
            _agentLocation!.location.latitude,
            _agentLocation!.location.longitude,
          ),
          width: 56,
          height: 56,
          child: Tooltip(
            message: isStale
                ? 'Assigned Agent (Location Stale)'
                : 'Assigned Agent (Live)',
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isStale ? Colors.amber.shade700 : const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: (isStale ? Colors.amber : Colors.green).withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.directions_car, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildTrackingBottomCard(ThemeData theme) {
    double? distanceKm;
    if (_request.location != null &&
        _agentLocation != null &&
        _assignment?.status.isAccepted == true) {
      distanceKm = GeoUtils.haversineDistanceKm(
        _request.location!.latitude,
        _request.location!.longitude,
        _agentLocation!.location.latitude,
        _agentLocation!.location.longitude,
      );
    }

    final isAgentStale = _agentLocation?.isStale(thresholdSeconds: 120) ?? false;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Row: Title, Priority, Status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _request.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Category: ${_request.category} • Created ${Formatters.formatTime(_request.createdAt)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                PriorityBadge(priority: _request.priority),
                const SizedBox(width: 8),
                StatusBadge.forRequest(_request.status),
              ],
            ),
            const Divider(height: 20),

            // Service Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _request.serviceAddress,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Agent & Distance Section (if assigned or in progress)
            if (_assignment?.status.isAccepted == true) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.green.shade700,
                      child: const Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _assignment?.agentProfile?.fullName.isNotEmpty == true
                                ? _assignment!.agentProfile!.fullName
                                : 'Assigned Agent',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          if (distanceKm != null)
                            Text(
                              '${distanceKm.toStringAsFixed(1)} km away from your location',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade900,
                              ),
                            )
                          else
                            Text(
                              'GPS location awaiting connection',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                    if (_agentLocation != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAgentStale ? Colors.amber.shade100 : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAgentStale ? Icons.warning_amber_rounded : Icons.sensors,
                              size: 14,
                              color: isAgentStale ? Colors.amber.shade900 : Colors.green.shade800,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isAgentStale ? 'Stale' : 'Live',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isAgentStale ? Colors.amber.shade900 : Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_request.status.canBeCancelledByCustomer) ...[
                  OutlinedButton(
                    onPressed: _isCancelling ? null : _cancelRequest,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                    ),
                    child: _isCancelling
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Cancel Request'),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_request.status.isPending || _request.status.isDispatching)
                  ElevatedButton.icon(
                    onPressed: _isDispatching ? null : _triggerDispatch,
                    icon: _isDispatching
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.radar, size: 16),
                    label: Text(
                      _request.status.isDispatching ? 'Retry Dispatch' : 'Dispatch Now',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

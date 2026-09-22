import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/priority_badge.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../models/service_assignment.dart';
import '../../../../models/service_request.dart';
import '../../../../services/geolocation_service.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../controllers/agent_controller.dart';
import '../controllers/agent_location_controller.dart';
import '../widgets/incoming_offer_card.dart';
import 'record_payment_dialog.dart';
import '../../../../core/constants/app_constants.dart';

/// Material 3 mobile navigation shell for Agents.
class AgentMobileShell extends ConsumerStatefulWidget {
  const AgentMobileShell({super.key});

  @override
  ConsumerState<AgentMobileShell> createState() => _AgentMobileShellState();
}

class _AgentMobileShellState extends ConsumerState<AgentMobileShell> {
  int _currentIndex = 0;
  final _radiusController = TextEditingController();
  bool _isEditingRadius = false;
  LocationPermissionStatus? _permissionStatus;
  bool _isCheckingPermission = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(agentDashboardProvider.notifier).loadAgentData();
      _checkLocationPermission();
    });
  }

  @override
  void dispose() {
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    setState(() => _isCheckingPermission = true);
    try {
      final geo = ref.read(geolocationServiceProvider);
      final status = await geo.checkPermission();
      if (mounted) {
        setState(() {
          _permissionStatus = status;
          _isCheckingPermission = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingPermission = false);
    }
  }

  Future<void> _requestLocationPermission() async {
    final geo = ref.read(geolocationServiceProvider);
    final status = await geo.requestPermission();
    if (mounted) {
      setState(() => _permissionStatus = status);
      if (status == LocationPermissionStatus.serviceDisabled) {
        geo.openLocationSettings();
      } else if (status == LocationPermissionStatus.permanentlyDenied) {
        geo.openAppSettings();
      }
    }
  }

  void _openRecordPayment(ServiceAssignment assignment) {
    showDialog(
      context: context,
      builder: (ctx) => RecordPaymentDialog(assignment: assignment),
    ).then((_) {
      ref.read(agentDashboardProvider.notifier).loadAgentData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final agentState = ref.watch(agentDashboardProvider);
    final activeJob = agentState.activeAssignment;
    final offersCount = agentState.incomingOffers.length;

    if (!_isEditingRadius && agentState.agentProfile != null) {
      _radiusController.text = agentState.serviceRadiusKm.toStringAsFixed(0);
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(agentState),
          _buildOffersTab(agentState),
          _buildActiveJobTab(activeJob),
          _buildProfileTab(agentState),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          setState(() => _currentIndex = idx);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: offersCount > 0,
              label: Text('$offersCount'),
              child: const Icon(Icons.notifications_active_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: offersCount > 0,
              label: Text('$offersCount'),
              child: const Icon(Icons.notifications_active),
            ),
            label: 'Offers',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: activeJob != null,
              child: const Icon(Icons.handyman_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: activeJob != null,
              child: const Icon(Icons.handyman),
            ),
            label: 'Active Job',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(AgentDashboardState state) {
    final profile = ref.watch(currentUserProfileProvider);
    final isAvailable = state.isAvailable;
    final activeJob = state.activeAssignment;

    return RefreshIndicator(
      onRefresh: () => ref.read(agentDashboardProvider.notifier).loadAgentData(),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: isAvailable ? const Color(0xFF10B981) : Colors.blueGrey,
                    child: const Icon(Icons.engineering, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agent Portal',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          profile?.fullName.isNotEmpty == true ? profile!.fullName : 'Service Agent',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAvailable ? Colors.green.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isAvailable ? Colors.green.shade300 : Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isAvailable ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isAvailable ? 'AVAILABLE' : 'OFFLINE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isAvailable ? Colors.green.shade800 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Availability Toggle Card
              Card(
                elevation: 0,
                color: isAvailable ? Colors.green.shade50.withValues(alpha: 0.6) : Colors.grey.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isAvailable ? Colors.green.shade300 : Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        isAvailable ? Icons.check_circle : Icons.do_not_disturb_on,
                        color: isAvailable ? Colors.green.shade700 : Colors.grey.shade600,
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAvailable ? 'Receiving Service Requests' : 'You are currently Offline',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              isAvailable
                                  ? 'Eligible for dispatch within your radius.'
                                  : 'Switch to Available to receive service jobs.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isAvailable,
                        activeThumbColor: Colors.green,
                        onChanged: (val) {
                          ref.read(agentDashboardProvider.notifier).setAvailability(val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Active Job Alert Card (if any)
              if (activeJob != null) ...[
                Card(
                  elevation: 2,
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.blue.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.handyman, color: Color(0xFF2563EB), size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'CURRENT ACTIVE JOB',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const Spacer(),
                            if (activeJob.request != null)
                              StatusBadge.forRequest(activeJob.request!.status),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          activeJob.request?.title ?? 'Active Service Assignment',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeJob.request?.serviceAddress ?? 'Address provided upon dispatch',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _currentIndex = 2),
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text('Open Active Job'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Service Radius Card
              Card(
                elevation: 0,
                color: Colors.grey.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Coverage & Service Radius',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dispatch engine matches requests within this coverage distance (${ServiceRadiusConstants.rangeHelpText}).',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: _radiusController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                suffixText: 'km',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => _isEditingRadius = true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: () {
                              final r = double.tryParse(_radiusController.text.trim());
                              if (r != null && ServiceRadiusConstants.isValid(r)) {
                                _isEditingRadius = false;
                                ref.read(agentDashboardProvider.notifier).updateServiceRadius(r);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Service radius saved!')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Enter a valid radius between ${ServiceRadiusConstants.minRadiusKm.toInt()} and ${ServiceRadiusConstants.maxRadiusKm.toInt()} km.',
                                    ),
                                  ),
                                );
                              }
                            },
                            child: const Text('Update Radius'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // GPS Hardware & Permission Status Card
              _buildLocationStatusCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationStatusCard() {
    final isGranted = _permissionStatus == LocationPermissionStatus.granted;
    final isDisabled = _permissionStatus == LocationPermissionStatus.serviceDisabled;

    return Card(
      elevation: 0,
      color: isGranted ? Colors.blue.shade50.withValues(alpha: 0.4) : Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isGranted ? Colors.blue.shade200 : Colors.amber.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isGranted ? Icons.gps_fixed : Icons.gps_not_fixed,
                  color: isGranted ? const Color(0xFF2563EB) : Colors.amber.shade900,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isGranted ? 'Device GPS Ready' : 'Location Setup Required',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isGranted ? Colors.black87 : Colors.amber.shade900,
                    ),
                  ),
                ),
                if (_isCheckingPermission)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isGranted
                  ? 'Real-time GPS will broadcast automatically when an accepted active job is in progress.'
                  : isDisabled
                      ? 'Device GPS is disabled. Please turn on Location in device settings.'
                      : 'Location permission is required to stream location to the customer during active jobs.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            if (!isGranted) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _requestLocationPermission,
                icon: const Icon(Icons.settings, size: 16),
                label: Text(isDisabled ? 'Enable Location' : 'Grant Permission'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOffersTab(AgentDashboardState state) {
    final offers = state.incomingOffers;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(agentDashboardProvider.notifier).loadAgentData(),
        child: offers.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  EmptyStateView(
                    icon: Icons.notifications_none,
                    title: 'No incoming offers',
                    message: state.isAvailable
                        ? 'You are Available! When a customer nearby requests service, offers will arrive here with a 120s timer.'
                        : 'You are currently Offline. Turn on Availability in Home to receive offers.',
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: offers.length,
                itemBuilder: (context, index) {
                  return IncomingOfferCard(offer: offers[index]);
                },
              ),
      ),
    );
  }

  Widget _buildActiveJobTab(ServiceAssignment? active) {
    if (active == null) {
      return SafeArea(
        child: Center(
          child: EmptyStateView(
            icon: Icons.assignment_outlined,
            title: 'No active job',
            message: 'You do not have any accepted jobs in progress right now.',
          ),
        ),
      );
    }

    final req = active.request;
    final locState = ref.watch(agentLocationControllerProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.engineering, color: Colors.green, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACTIVE JOB ASSIGNMENT',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        Text(
                          req?.status == RequestStatus.inProgress
                              ? 'Service in progress'
                              : 'Accepted — Please proceed to address',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (req != null) StatusBadge.forRequest(req.status),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Job Details Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            req?.title ?? 'Service Request',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        if (req != null) PriorityBadge(priority: req.priority),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Category: ${req?.category ?? "General"}',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                    const Divider(height: 24),

                    // Destination Address
                    const Text('Service Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.place, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            req?.serviceAddress ?? 'Not specified',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),

                    if (req?.description != null && req!.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Notes / Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(req.description!, style: const TextStyle(fontSize: 13)),
                    ],

                    // Customer Privacy (Correction 8: only what is authorized)
                    if (req?.customerProfile != null && req!.customerProfile!.fullName.isNotEmpty) ...[
                      const Divider(height: 24),
                      const Text('Customer Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(req.customerProfile!.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (req.customerProfile!.phone != null && req.customerProfile!.phone!.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Text('(${req.customerProfile!.phone})', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Live Location Sharing Beacon Card
            Card(
              elevation: 0,
              color: locState.isPublishing ? Colors.green.shade50 : Colors.amber.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: locState.isPublishing ? Colors.green.shade300 : Colors.amber.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  children: [
                    Icon(
                      locState.isPublishing ? Icons.sensors : Icons.sensors_off,
                      color: locState.isPublishing ? Colors.green.shade800 : Colors.amber.shade800,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locState.isPublishing ? 'GPS Broadcasting to Customer' : 'GPS Broadcast Idle',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: locState.isPublishing ? Colors.green.shade900 : Colors.amber.shade900,
                            ),
                          ),
                          if (locState.lastPublishedAt != null)
                            Text(
                              'Last published: ${Formatters.formatTime(locState.lastPublishedAt)}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Lifecycle Workflow Actions
            if (req?.status == RequestStatus.assigned)
              ElevatedButton.icon(
                onPressed: () async {
                  await ref.read(agentDashboardProvider.notifier).startService(active.id, active.requestId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Service marked in progress!'), backgroundColor: Colors.green),
                    );
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Service (Arrived on Site)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

            if (req?.status == RequestStatus.inProgress) ...[
              ElevatedButton.icon(
                onPressed: () async {
                  final noteController = TextEditingController();
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Complete Service'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Are you sure you want to mark this service request as completed?'),
                          const SizedBox(height: 16),
                          TextField(
                            controller: noteController,
                            decoration: const InputDecoration(
                              labelText: 'Completion Notes (Optional)',
                              hintText: 'e.g., Replaced valve, cleaned filters',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Yes, Complete', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final noteText = noteController.text.trim().isNotEmpty ? noteController.text.trim() : null;
                    await ref.read(agentDashboardProvider.notifier).completeService(
                      active.id,
                      active.requestId,
                      note: noteText,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Service completed successfully!'), backgroundColor: Colors.green),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.task_alt),
                label: const Text('Complete Service'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _openRecordPayment(active),
                icon: const Icon(Icons.receipt_long),
                label: const Text('Record Payment'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab(AgentDashboardState state) {
    final profile = ref.watch(currentUserProfileProvider);
    final agentProfile = state.agentProfile;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Center(
              child: CircleAvatar(
                radius: 46,
                backgroundColor: const Color(0xFF10B981),
                child: Text(
                  profile?.fullName.isNotEmpty == true ? profile!.fullName[0].toUpperCase() : 'A',
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                profile?.fullName.isNotEmpty == true ? profile!.fullName : 'Service Agent',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  agentProfile?.isVerified == true ? 'Verified Agent' : 'Agent Profile',
                  style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Profile Info
            Card(
              elevation: 0,
              color: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.phone_outlined, color: Colors.green),
                    title: const Text('Phone Number', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    subtitle: Text(
                      profile?.phone != null && profile!.phone!.isNotEmpty ? profile.phone! : 'Not provided',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.radar, color: Colors.green),
                    title: const Text('Service Radius', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    subtitle: Text(
                      '${state.serviceRadiusKm.toStringAsFixed(0)} km coverage',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.sensors, color: Colors.green),
                    title: const Text('Location Permission', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    subtitle: Text(
                      _permissionStatus == LocationPermissionStatus.granted
                          ? 'Granted'
                          : _permissionStatus == LocationPermissionStatus.serviceDisabled
                              ? 'GPS Disabled'
                              : 'Denied / Not Granted',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _permissionStatus == LocationPermissionStatus.granted ? Colors.green : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Logout Button
            OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to log out of QuickServe?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Log Out', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(agentLocationControllerProvider.notifier).stopPublishing();
                  ref.read(authControllerProvider.notifier).signOut();
                }
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Log Out', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

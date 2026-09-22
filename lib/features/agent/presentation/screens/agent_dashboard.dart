import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/dashboard_shell.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/priority_badge.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/service_assignment.dart';
import '../../../../models/user_role.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../controllers/agent_controller.dart';
import 'record_payment_dialog.dart';
import '../widgets/incoming_offer_card.dart';
import '../widgets/agent_location_sharing_card.dart';
import '../../../../core/constants/app_constants.dart';

class AgentDashboard extends ConsumerStatefulWidget {
  const AgentDashboard({super.key});

  @override
  ConsumerState<AgentDashboard> createState() => _AgentDashboardState();
}

class _AgentDashboardState extends ConsumerState<AgentDashboard> {
  final _radiusController = TextEditingController();
  bool _isEditingRadius = false;

  @override
  void dispose() {
    _radiusController.dispose();
    super.dispose();
  }

  void _openRecordPaymentDialog(ServiceAssignment assignment) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RecordPaymentDialog(assignment: assignment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider);
    final state = ref.watch(agentDashboardProvider);
    final theme = Theme.of(context);

    if (!_isEditingRadius && state.agentProfile != null) {
      _radiusController.text = state.serviceRadiusKm.toStringAsFixed(0);
    }

    return DashboardShell(
      title: 'Agent Dashboard',
      role: UserRole.agent,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Welcome Header
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.indigo.shade600,
                  child: const Icon(Icons.support_agent, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${profile?.fullName.isNotEmpty == true ? profile!.fullName : "Agent"}!',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage your availability, incoming service offers, and active jobs.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Dashboard',
                  onPressed: () {
                    ref.read(agentDashboardProvider.notifier).loadAgentData();
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (state.errorMessage != null) ...[
              ErrorView(
                message: state.errorMessage!,
                onRetry: () => ref.read(agentDashboardProvider.notifier).loadAgentData(),
              ),
              const SizedBox(height: 16),
            ],

            // Availability & Radius Controls Row
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    // Availability Switch
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: state.isAvailable ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          state.isAvailable ? 'Status: Available' : 'Status: Offline',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(width: 12),
                        Switch(
                          value: state.isAvailable,
                          activeThumbColor: Colors.green,
                          onChanged: (val) {
                            ref.read(agentDashboardProvider.notifier).setAvailability(val);
                          },
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Radius Configuration
                    Row(
                      children: [
                        const Icon(Icons.radar, size: 18, color: Colors.indigo),
                        const SizedBox(width: 8),
                        Text(
                          'Service Radius (${ServiceRadiusConstants.rangeHelpText}): ',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: _radiusController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            onChanged: (_) => _isEditingRadius = true,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('km', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () {
                            final r = double.tryParse(_radiusController.text.trim());
                            if (r != null && ServiceRadiusConstants.isValid(r)) {
                              _isEditingRadius = false;
                              ref.read(agentDashboardProvider.notifier).updateServiceRadius(r);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Service radius updated!')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Enter a radius between ${ServiceRadiusConstants.minRadiusKm.toInt()} and ${ServiceRadiusConstants.maxRadiusKm.toInt()} km.',
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text('Save', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Location Sharing Card
            if (profile != null) ...[
              AgentLocationSharingCard(agentId: profile.id),
              const SizedBox(height: 24),
            ],

            // Active Job Card (if assigned/accepted)
            if (state.activeAssignment != null) ...[
              _buildActiveJobCard(state.activeAssignment!),
              const SizedBox(height: 28),
            ],

            // Incoming Offers Section
            Text(
              'Incoming Service Offers (${state.incomingOffers.length})',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (state.incomingOffers.isEmpty)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: const EmptyStateView(
                  icon: Icons.notifications_none,
                  title: 'No Incoming Offers',
                  message: 'When service requests are assigned directly to you, they will appear here with an offer timer.',
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.incomingOffers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final offer = state.incomingOffers[index];
                  return IncomingOfferCard(offer: offer);
                },
              ),
            const SizedBox(height: 32),

            // Open Customer Requests Section
            Row(
              children: [
                Text(
                  'Open Requests Nearby (${state.openRequests.length})',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Available',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.openRequests.isEmpty)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: const EmptyStateView(
                  icon: Icons.work_outline,
                  title: 'No Open Requests',
                  message: 'There are currently no unassigned customer requests. New requests will appear here live.',
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.openRequests.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final req = state.openRequests[index];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.blue.shade200, width: 1.2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.handyman, color: Colors.blue, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      req.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Category: ${req.category} • Created ${Formatters.formatTime(req.createdAt)}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              PriorityBadge(priority: req.priority),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  req.serviceAddress,
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (req.description != null && req.description!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                req.description!,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    ref
                                        .read(agentDashboardProvider.notifier)
                                        .dismissPendingRequest(req.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Request dismissed from view.'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                  label: const Text(
                                    'Decline',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.red.shade300),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: state.activeAssignment != null
                                      ? null
                                      : () async {
                                          final success = await ref
                                              .read(agentDashboardProvider.notifier)
                                              .claimPendingRequest(req.id);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  success
                                                      ? 'Service Request Accepted & Assigned!'
                                                      : 'Could not accept request. It may have been claimed by another agent.',
                                                ),
                                                backgroundColor:
                                                    success ? Colors.green : Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                  icon: const Icon(Icons.check_circle_outline, size: 18),
                                  label: Text(
                                    state.activeAssignment != null
                                        ? 'Finish Active Job First'
                                        : 'Accept & Claim',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 32),

            // Assignment History Section
            Text(
              'Assignment History',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: state.history.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.history,
                        title: 'No Past Assignments',
                        message: 'Completed and closed assignments will be archived here.',
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.history.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = state.history[index];
                          final req = item.request;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            title: Text(
                              req?.title ?? 'Service Request (${item.requestId})',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Text(
                              'Category: ${req?.category ?? "General"} • Customer: ${req?.customerProfile?.fullName ?? "Customer"} • ${Formatters.formatDate(item.createdAt)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            trailing: StatusBadge.forAssignment(item.status),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveJobCard(ServiceAssignment assignment) {
    final req = assignment.request;
    final isInProgress = req?.status.isInProgress == true;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.indigo.shade300, width: 1.5),
      ),
      color: Colors.indigo.shade50.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'CURRENT ACTIVE JOB',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                if (req != null) StatusBadge.forRequest(req.status),
                const Spacer(),
                if (assignment.acceptedAt != null)
                  Text(
                    'Accepted: ${Formatters.formatDateTime(assignment.acceptedAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.indigo.shade900),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              req != null ? '${req.formattedId} • ${req.title}' : 'Service Request',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              'Customer: ${req?.customerProfile?.fullName ?? "Customer"} • Address: ${req?.serviceAddress ?? "Not specified"}',
              style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
            ),
            if (req?.description != null) ...[
              const SizedBox(height: 6),
              Text(
                req!.description!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isInProgress)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Service'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                    onPressed: () {
                      ref
                          .read(agentDashboardProvider.notifier)
                          .startService(assignment.id, assignment.requestId);
                    },
                  )
                else ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.payment, color: Colors.green),
                    label: const Text('Record Payment', style: TextStyle(color: Colors.green)),
                    onPressed: () => _openRecordPaymentDialog(assignment),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Complete Service'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
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
                              const Text('Mark this service request as completed?'),
                              const SizedBox(height: 16),
                              TextField(
                                controller: noteController,
                                decoration: const InputDecoration(
                                  labelText: 'Completion Notes (Optional)',
                                  hintText: 'e.g., Repaired pipe, verified with customer',
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
                        await ref
                            .read(agentDashboardProvider.notifier)
                            .completeService(assignment.id, assignment.requestId, note: noteText);
                        if (mounted) {
                          _openRecordPaymentDialog(assignment);
                        }
                      }
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/dashboard_shell.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/quickserve_components.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../models/service_assignment.dart';
import '../../../../models/user_role.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../controllers/agent_controller.dart';
import '../controllers/agent_location_controller.dart';
import '../widgets/agent_location_sharing_card.dart';
import '../widgets/incoming_offer_card.dart';
import '../../../../core/widgets/in_app_route_map_card.dart';
import 'record_payment_dialog.dart';

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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider);
    final state = ref.watch(agentDashboardProvider);
    final theme = Theme.of(context);
    final agentName = profile?.fullName.isNotEmpty == true ? profile!.fullName : "Agent";

    if (!_isEditingRadius && state.agentProfile != null) {
      _radiusController.text = state.serviceRadiusKm.toStringAsFixed(0);
    }

    return DashboardShell(
      title: 'Agent Portal',
      role: UserRole.agent,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Welcome Header
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: state.isAvailable ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: state.isAvailable ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.engineering_rounded,
                      color: state.isAvailable ? const Color(0xFF10B981) : const Color(0xFF64748B),
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getGreeting()}, $agentName',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Manage your availability, incoming service offers, and active jobs.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
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

            // Availability Control Card
            QuickServeCard(
              padding: const EdgeInsets.all(20),
              backgroundColor: state.isAvailable ? const Color(0xFFF0FDF4) : Colors.white,
              borderColor: state.isAvailable ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
              child: Row(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: state.isAvailable ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        state.isAvailable ? 'Status: ● Online' : 'Status: ○ Offline',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: state.isAvailable ? const Color(0xFF065F46) : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Switch(
                        value: state.isAvailable,
                        activeTrackColor: const Color(0xFF10B981),
                        onChanged: (val) {
                          ref.read(agentDashboardProvider.notifier).setAvailability(val);
                        },
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.radar_rounded, size: 18, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text(
                        'Service Radius (${ServiceRadiusConstants.rangeHelpText}): ',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)),
                      ),
                      SizedBox(
                        width: 64,
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
                      const Text('km', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      const SizedBox(width: 8),
                      ElevatedButton(
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        child: const Text('Save', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Location Sharing Card (Only shown when idle / no active assignment)
            if (profile != null && state.activeAssignment == null) ...[
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
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            if (state.incomingOffers.isEmpty)
              const QuickServeCard(
                child: EmptyStateView(
                  icon: Icons.notifications_none_rounded,
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

            // Assignment History Section
            Text(
              'Completed & Past Jobs',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            QuickServeCard(
              padding: const EdgeInsets.all(16.0),
              child: state.history.isEmpty
                  ? const EmptyStateView(
                      icon: Icons.history_rounded,
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
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
                          ),
                          subtitle: Text(
                            'Category: ${req?.category ?? "General"} • Customer: ${req?.customerProfile?.fullName ?? "Customer"} • ${Formatters.formatDate(item.createdAt)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          trailing: StatusBadge.forAssignment(item.status),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSetEtaDialog(String requestId, DateTime? currentEta) async {
    final now = DateTime.now();

    DateTime selectedEta = currentEta ?? now.add(const Duration(minutes: 30));

    final result = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final diffMins = selectedEta.difference(DateTime.now()).inMinutes;
            final durationText = diffMins > 0
                ? 'Approximately $diffMins minutes away'
                : 'Selected time is in the past';

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.access_time_filled_rounded, color: Color(0xFF10B981), size: 24),
                      const SizedBox(width: 10),
                      const Text(
                        'Set Estimated Arrival Time (ETA)',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Selected Time Display Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estimated Arrival',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.formatTime(selectedEta),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                        ),
                        Text(
                          durationText,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Preset Chips
                  const Text('Quick Select Preset:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [15, 30, 45, 60].map((mins) {
                      final target = DateTime.now().add(Duration(minutes: mins));
                      return ChoiceChip(
                        label: Text('+$mins min'),
                        selected: (selectedEta.difference(target).inMinutes.abs()) < 3,
                        selectedColor: const Color(0xFFEFF6FF),
                        labelStyle: TextStyle(
                          color: (selectedEta.difference(target).inMinutes.abs()) < 3
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF334155),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() {
                              selectedEta = DateTime.now().add(Duration(minutes: mins));
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Custom Time Picker Button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: const Text('Pick Custom Date & Time'),
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedEta,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (pickedDate == null) return;
                      if (!context.mounted) return;

                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedEta),
                      );
                      if (pickedTime == null) return;

                      setModalState(() {
                        selectedEta = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Confirm Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop(selectedEta);
                    },
                    child: const Text('Save & Broadcast ETA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      final success = await ref
          .read(agentDashboardProvider.notifier)
          .updateEstimatedArrival(requestId, result);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Estimated arrival time updated and broadcast to customer!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to update the ETA. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildActiveJobCard(ServiceAssignment assignment) {
    final req = assignment.request;
    final isInProgress = req?.status.isInProgress == true;
    final agentLocState = ref.watch(agentLocationControllerProvider);

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF93C5FD), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'CURRENT ACTIVE JOB',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(width: 8),
              if (req != null) StatusBadge.forRequest(req.status),
              const Spacer(),
              if (assignment.acceptedAt != null)
                Text(
                  'Accepted: ${Formatters.formatDateTime(assignment.acceptedAt)}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            req != null ? '${req.formattedId} • ${req.title}' : 'Service Request',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Text(
            'Customer: ${req?.customerProfile?.fullName ?? "Customer"}',
            style: const TextStyle(color: Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (req?.description != null) ...[
            const SizedBox(height: 6),
            Text(
              req!.description!,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),

          // Interactive In-App Route Map & Directions Section
          InAppRouteMapCard(
            customerLocation: req?.location,
            customerAddress: req?.serviceAddress ?? 'Address unavailable',
            agentLocation: agentLocState.currentLocation,
            agentName: 'You',
            height: 280,
          ),
          const SizedBox(height: 16),

          // Estimated Arrival (ETA) Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.access_time_filled_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimated Arrival',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        req?.estimatedArrival != null
                            ? Formatters.formatDateTime(req!.estimatedArrival)
                            : 'Not provided yet',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: req?.estimatedArrival != null ? const Color(0xFF047857) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (req != null && (req.status.isAssigned || req.status.isInProgress))
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                    label: Text(
                      req.estimatedArrival != null ? 'Update ETA' : 'Set ETA',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF047857),
                      side: const BorderSide(color: Color(0xFF34D399)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showSetEtaDialog(req.id, req.estimatedArrival),
                  ),
              ],
            ),
          ),
          const Divider(height: 28),

          // Lifecycle Buttons (Assigned -> In Progress -> Completed)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isInProgress)
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start Service', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    ref.read(agentDashboardProvider.notifier).startService(assignment.id, assignment.requestId);
                  },
                )
              else ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.payment_rounded, color: Color(0xFF10B981)),
                  label: const Text('Record Payment', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFA7F3D0)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _openRecordPaymentDialog(assignment),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Complete Service', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
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
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
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
    );
  }
}

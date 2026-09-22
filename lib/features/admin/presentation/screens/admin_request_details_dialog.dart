import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/priority_badge.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../models/service_request.dart';
import '../../../../models/service_assignment.dart';
import '../../../../models/payment_record.dart';
import '../../../../models/request_status_history.dart';
import '../../../../models/user_profile.dart';
import '../../../../repositories/repository_providers.dart';
import 'manual_assign_dialog.dart';

class AdminRequestDetailsDialog extends ConsumerStatefulWidget {
  final ServiceRequest request;

  const AdminRequestDetailsDialog({super.key, required this.request});

  @override
  ConsumerState<AdminRequestDetailsDialog> createState() =>
      _AdminRequestDetailsDialogState();
}

class _AdminRequestDetailsDialogState
    extends ConsumerState<AdminRequestDetailsDialog> {
  bool _isLoadingExtra = true;
  UserProfile? _customer;
  ServiceAssignment? _assignment;
  List<RequestStatusHistory> _history = [];
  PaymentRecord? _payment;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final assignRepo = ref.read(assignmentRepositoryProvider);
      final historyRepo = ref.read(statusHistoryRepositoryProvider);
      final paymentRepo = ref.read(paymentRepositoryProvider);
      final profileRepo = ref.read(profileRepositoryProvider);

      final results = await Future.wait([
        assignRepo.getAssignmentForRequest(widget.request.id),
        historyRepo.getHistoryForRequest(widget.request.id),
        paymentRepo.getPaymentForRequest(widget.request.id),
        profileRepo.getProfileOrNull(widget.request.customerId),
      ]);

      if (mounted) {
        setState(() {
          _assignment = results[0] as ServiceAssignment?;
          _history = results[1] as List<RequestStatusHistory>;
          _payment = results[2] as PaymentRecord?;
          _customer = results[3] as UserProfile?;
          _isLoadingExtra = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingExtra = false);
    }
  }

  void _openManualAssign() async {
    final assigned = await showDialog<bool>(
      context: context,
      builder: (ctx) => ManualAssignDialog(request: widget.request),
    );
    if (assigned == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StatusBadge.forRequest(req.status),
                            const SizedBox(width: 8),
                            PriorityBadge(priority: req.priority),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                req.category,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          req.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Request & Customer Overview Card
                      Card(
                        elevation: 0,
                        color: Colors.grey.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _infoRow(Icons.pin, 'Request ID', req.formattedId),
                              const SizedBox(height: 8),
                              _infoRow(Icons.fingerprint, 'System UUID', req.id),
                              const SizedBox(height: 8),
                              _infoRow(
                                Icons.calendar_today_outlined,
                                'Created',
                                Formatters.formatDateTime(req.createdAt),
                              ),
                              const SizedBox(height: 8),
                              _infoRow(
                                Icons.person_outline,
                                'Customer',
                                _customer != null
                                    ? '${_customer!.fullName} (${_customer!.phone ?? "No phone"})'
                                    : 'Customer ID: ${req.customerId}',
                              ),
                              const SizedBox(height: 8),
                              _infoRow(
                                  Icons.place_outlined, 'Service Address', req.serviceAddress),
                              if (req.location != null) ...[
                                const SizedBox(height: 8),
                                _infoRow(
                                  Icons.gps_fixed,
                                  'Coordinates',
                                  'Lat: ${req.location!.latitude.toStringAsFixed(4)}, Lon: ${req.location!.longitude.toStringAsFixed(4)}',
                                ),
                              ],
                              if (req.description != null &&
                                  req.description!.isNotEmpty) ...[
                                const Divider(height: 20),
                                Text(
                                  'Description',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  req.description!,
                                  style: TextStyle(
                                      color: Colors.grey.shade700, fontSize: 13),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Assigned Agent Card
                      Text(
                        'Assignment Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_assignment != null)
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.indigo.shade100),
                          ),
                          color: Colors.indigo.shade50.withValues(alpha: 0.3),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.indigo.shade600,
                                  child: const Icon(Icons.support_agent,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _assignment!.agentProfile?.fullName.isNotEmpty ==
                                                true
                                            ? _assignment!.agentProfile!.fullName
                                            : 'Agent ID: ${_assignment!.agentId}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Status: ${_assignment!.status.displayName}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700),
                                      ),
                                      if (_assignment!.offeredAt != null)
                                        Text(
                                          'Offered: ${Formatters.formatDateTime(_assignment!.offeredAt)}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600),
                                        ),
                                      if (_assignment!.acceptedAt != null)
                                        Text(
                                          'Accepted: ${Formatters.formatDateTime(_assignment!.acceptedAt)}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600),
                                        ),
                                      if (_assignment!.completedAt != null)
                                        Text(
                                          'Completed: ${Formatters.formatDateTime(_assignment!.completedAt)}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600),
                                        ),
                                    ],
                                  ),
                                ),
                                StatusBadge.forAssignment(_assignment!.status),
                              ],
                            ),
                          ),
                        )
                      else
                        Card(
                          elevation: 0,
                          color: Colors.amber.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.amber.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.amber.shade800),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'No agent currently assigned to this request.',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                                if (req.status.isPending)
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.person_add, size: 16),
                                    label: const Text('Assign Now'),
                                    onPressed: _openManualAssign,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Payment Record Card (if any)
                      if (_payment != null) ...[
                        Text(
                          'Payment Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.green.shade200),
                          ),
                          color: Colors.green.shade50.withValues(alpha: 0.4),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.green.shade600,
                                  child: const Icon(Icons.check,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        Formatters.formatCurrency(
                                            _payment!.amount,
                                            currency: _payment!.currency),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        'Method: ${_payment!.method.displayName} • Status: ${_payment!.status.displayName}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700),
                                      ),
                                      if (_payment!.paidAt != null)
                                        Text(
                                          'Paid on: ${Formatters.formatDateTime(_payment!.paidAt)}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600),
                                        ),
                                    ],
                                  ),
                                ),
                                StatusBadge.forPayment(_payment!.status),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Status History Timeline
                      Text(
                        'Status History Timeline',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingExtra)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_history.isEmpty)
                        Text(
                          'No history logged yet.',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            final h = _history[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              h.newStatus.displayName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              Formatters.formatDateTime(
                                                  h.createdAt),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (h.note != null &&
                                            h.note!.isNotEmpty)
                                          Text(
                                            h.note!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (req.status.isPending && _assignment == null)
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.person_add, size: 16),
                        label: const Text('Assign Agent'),
                        onPressed: _openManualAssign,
                      ),
                    ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.grey.shade700),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

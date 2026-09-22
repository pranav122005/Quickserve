import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/priority_badge.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../models/payment_record.dart';
import '../../../../models/request_status_history.dart';
import '../../../../models/service_request.dart';
import '../../../../repositories/repository_providers.dart';
import '../screens/customer_tracking_screen.dart';

/// Modal bottom sheet displaying comprehensive request details and payment status for mobile.
class CustomerRequestDetailsSheet extends ConsumerStatefulWidget {
  final ServiceRequest request;
  final VoidCallback? onRequestCancelled;

  const CustomerRequestDetailsSheet({
    super.key,
    required this.request,
    this.onRequestCancelled,
  });

  @override
  ConsumerState<CustomerRequestDetailsSheet> createState() =>
      _CustomerRequestDetailsSheetState();
}

class _CustomerRequestDetailsSheetState
    extends ConsumerState<CustomerRequestDetailsSheet> {
  PaymentRecord? _payment;
  List<RequestStatusHistory> _history = [];
  bool _isLoadingDetails = true;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final paymentRepo = ref.read(paymentRepositoryProvider);
      final historyRepo = ref.read(statusHistoryRepositoryProvider);
      final results = await Future.wait([
        paymentRepo.getPaymentForRequest(widget.request.id),
        historyRepo.getHistoryForRequest(widget.request.id),
      ]);
      if (mounted) {
        setState(() {
          _payment = results[0] as PaymentRecord?;
          _history = results[1] as List<RequestStatusHistory>;
          _isLoadingDetails = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingDetails = false);
      }
    }
  }

  Future<void> _handleCancel() async {
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
      await repo.cancelRequest(widget.request.id);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onRequestCancelled?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service request cancelled.'),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final req = widget.request;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              // Drag Handle
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

              // Flipkart/Swiggy-Style Status Progress Stepper
              _buildStatusStepper(req),

              // Title & Badges
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      req.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PriorityBadge(priority: req.priority),
                  const SizedBox(width: 8),
                  StatusBadge.forRequest(req.status),
                ],
              ),
              const SizedBox(height: 12),

              // Request ID, Category & Created Date
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blueGrey.shade200),
                    ),
                    child: Text(
                      req.formattedId,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      req.category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      Formatters.formatDateTime(req.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),

              // Service Address
              const Text(
                'Service Address',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place_outlined, size: 18, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      req.serviceAddress,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              if (req.location != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 26.0),
                  child: Text(
                    'GPS: ${req.location!.latitude.toStringAsFixed(4)}, ${req.location!.longitude.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Description (if present)
              if (req.description != null && req.description!.trim().isNotEmpty) ...[
                const Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  req.description!,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
              ],

              // Payment Information Section
              const Divider(height: 24),
              const Text(
                'Payment Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              if (_isLoadingDetails)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_payment != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _payment!.status.isPaid ? Colors.green.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _payment!.status.isPaid ? Colors.green.shade200 : Colors.amber.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Amount Due / Paid:'),
                          Text(
                            Formatters.formatCurrency(_payment!.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Payment Method:'),
                          Text(_payment!.method.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Status:'),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _payment!.status.isPaid ? Colors.green : Colors.amber.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _payment!.status.displayName,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      if (_payment!.paidAt != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Paid At:'),
                            Text(
                              Formatters.formatDateTime(_payment!.paidAt),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.payment_outlined, size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'No payment recorded yet.',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ],
                  ),
                ),

              // Status History Timeline
              const SizedBox(height: 20),
              const Text(
                'Status History',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              if (_isLoadingDetails)
                const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
              else if (_history.isEmpty)
                Text('No status transitions recorded yet.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _history.length,
                  itemBuilder: (context, idx) {
                    final h = _history[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      h.newStatus.displayName,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    const Spacer(),
                                    Text(
                                      Formatters.formatDateTime(h.createdAt),
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                                if (h.note != null && h.note!.isNotEmpty)
                                  Text(
                                    h.note!,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),

              // Action Buttons
              if (req.status.isActive) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CustomerTrackingScreen(
                          requestId: req.id,
                          initialRequest: req,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.location_on, size: 18),
                  label: const Text('Track Live'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              if (req.status.canBeCancelledByCustomer) ...[
                OutlinedButton(
                  onPressed: _isCancelling ? null : _handleCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isCancelling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Cancel Request'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusStepper(ServiceRequest req) {
    int currentStep = 1;
    if (req.status.isCompleted) {
      currentStep = 5;
    } else if (req.status.isInProgress) {
      currentStep = 4;
    } else if (req.status.isAssigned) {
      currentStep = 3;
    } else if (req.status.isPending || req.status.isDispatching) {
      currentStep = 2;
    }

    final isCancelled = req.status.isCancelled;

    final steps = [
      {'title': 'Placed', 'icon': Icons.assignment_turned_in},
      {'title': 'Matching', 'icon': Icons.radar},
      {'title': 'Assigned', 'icon': Icons.person_pin_circle},
      {'title': 'In Progress', 'icon': Icons.engineering},
      {'title': 'Completed', 'icon': Icons.check_circle},
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isCancelled ? Colors.red.shade50 : Colors.blue.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                final stepIdx = (index - 1) ~/ 2 + 1;
                final isPassed = currentStep > stepIdx;
                return Expanded(
                  child: Container(
                    height: 2.5,
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
                stepColor = Colors.blue.shade700;
              } else {
                stepColor = Colors.grey.shade400;
              }

              return Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDone || isCurrent ? stepColor : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: stepColor, width: 2),
                    ),
                    child: Icon(
                      steps[stepIdx - 1]['icon'] as IconData,
                      size: 14,
                      color: isDone || isCurrent ? Colors.white : stepColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steps[stepIdx - 1]['title'] as String,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent ? stepColor : Colors.grey.shade700,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

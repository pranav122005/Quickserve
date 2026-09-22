import 'package:flutter/material.dart';
import '../../models/service_request.dart';
import '../../models/service_assignment.dart';
import '../../models/payment_record.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  factory StatusBadge.forRequest(RequestStatus status) {
    Color c;
    switch (status) {
      case RequestStatus.pending:
        c = Colors.orange.shade700;
        break;
      case RequestStatus.dispatching:
        c = Colors.blue.shade700;
        break;
      case RequestStatus.assigned:
        c = Colors.indigo.shade700;
        break;
      case RequestStatus.inProgress:
        c = Colors.purple.shade700;
        break;
      case RequestStatus.completed:
        c = Colors.green.shade700;
        break;
      case RequestStatus.cancelled:
        c = Colors.red.shade700;
        break;
    }
    return StatusBadge(label: status.displayName, color: c);
  }

  factory StatusBadge.forAssignment(AssignmentStatus status) {
    Color c;
    switch (status) {
      case AssignmentStatus.offered:
        c = Colors.amber.shade800;
        break;
      case AssignmentStatus.accepted:
        c = Colors.indigo.shade700;
        break;
      case AssignmentStatus.rejected:
        c = Colors.red.shade700;
        break;
      case AssignmentStatus.cancelled:
        c = Colors.grey.shade700;
        break;
      case AssignmentStatus.completed:
        c = Colors.green.shade700;
        break;
    }
    return StatusBadge(label: status.displayName, color: c);
  }

  factory StatusBadge.forPayment(PaymentStatus status) {
    Color c;
    switch (status) {
      case PaymentStatus.paid:
        c = Colors.green.shade700;
        break;
      case PaymentStatus.pending:
        c = Colors.amber.shade800;
        break;
      case PaymentStatus.failed:
        c = Colors.red.shade700;
        break;
    }
    return StatusBadge(label: status.displayName, color: c);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

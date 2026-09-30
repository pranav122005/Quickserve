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
        c = const Color(0xFFD97706); // Amber 600
        break;
      case RequestStatus.dispatching:
        c = const Color(0xFF2563EB); // Blue 600
        break;
      case RequestStatus.assigned:
        c = const Color(0xFF4F46E5); // Indigo 600
        break;
      case RequestStatus.inProgress:
        c = const Color(0xFF9333EA); // Purple 600
        break;
      case RequestStatus.completed:
        c = const Color(0xFF10B981); // Emerald 500
        break;
      case RequestStatus.cancelled:
        c = const Color(0xFFEF4444); // Red 500
        break;
    }
    return StatusBadge(label: status.displayName, color: c);
  }

  factory StatusBadge.forAssignment(AssignmentStatus status) {
    Color c;
    switch (status) {
      case AssignmentStatus.offered:
        c = const Color(0xFFD97706);
        break;
      case AssignmentStatus.accepted:
        c = const Color(0xFF4F46E5);
        break;
      case AssignmentStatus.rejected:
        c = const Color(0xFFEF4444);
        break;
      case AssignmentStatus.cancelled:
        c = const Color(0xFF64748B);
        break;
      case AssignmentStatus.completed:
        c = const Color(0xFF10B981);
        break;
    }
    return StatusBadge(label: status.displayName, color: c);
  }

  factory StatusBadge.forPayment(PaymentStatus status) {
    Color c;
    switch (status) {
      case PaymentStatus.paid:
        c = const Color(0xFF10B981);
        break;
      case PaymentStatus.pending:
        c = const Color(0xFFD97706);
        break;
      case PaymentStatus.failed:
        c = const Color(0xFFEF4444);
        break;
    }
    return StatusBadge(label: status.displayName, color: c);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

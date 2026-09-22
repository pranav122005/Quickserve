import 'package:flutter/material.dart';
import '../../models/service_request.dart';

class PriorityBadge extends StatelessWidget {
  final RequestPriority priority;

  const PriorityBadge({super.key, required this.priority});

  Color _getColor() {
    switch (priority) {
      case RequestPriority.low:
        return Colors.blueGrey;
      case RequestPriority.normal:
        return const Color(0xFF2563EB);
      case RequestPriority.high:
        return Colors.orange.shade800;
      case RequestPriority.urgent:
        return Colors.red.shade700;
    }
  }

  IconData _getIcon() {
    switch (priority) {
      case RequestPriority.low:
        return Icons.arrow_downward;
      case RequestPriority.normal:
        return Icons.remove;
      case RequestPriority.high:
        return Icons.arrow_upward;
      case RequestPriority.urgent:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIcon(), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            priority.displayName,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

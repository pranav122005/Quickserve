import 'package:flutter/material.dart';
import '../../models/service_request.dart';

class PriorityBadge extends StatelessWidget {
  final RequestPriority priority;

  const PriorityBadge({super.key, required this.priority});

  Color _getColor() {
    switch (priority) {
      case RequestPriority.low:
        return const Color(0xFF64748B); // Slate 500
      case RequestPriority.normal:
        return const Color(0xFF2563EB); // Blue 600
      case RequestPriority.high:
        return const Color(0xFFD97706); // Amber 600
      case RequestPriority.urgent:
        return const Color(0xFFEF4444); // Red 500
    }
  }

  IconData _getIcon() {
    switch (priority) {
      case RequestPriority.low:
        return Icons.arrow_downward_rounded;
      case RequestPriority.normal:
        return Icons.remove_rounded;
      case RequestPriority.high:
        return Icons.arrow_upward_rounded;
      case RequestPriority.urgent:
        return Icons.bolt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
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
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

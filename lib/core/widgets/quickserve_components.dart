import 'package:flutter/material.dart';

/// Reusable Card component for QuickServe design language
class QuickServeCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color borderColor;
  final double borderRadius;

  const QuickServeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20.0),
    this.onTap,
    this.backgroundColor = Colors.white,
    this.borderColor = const Color(0xFFE2E8F0),
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      );
    }

    return content;
  }
}

/// Reusable Stat KPI Card for SaaS dashboard
class QuickServeStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const QuickServeStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor = const Color(0xFF2563EB),
    this.iconBgColor = const Color(0xFFEFF6FF),
  });

  @override
  Widget build(BuildContext context) {
    return QuickServeCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Category Helper to get clean icons & colors for Service Categories
class ServiceCategoryHelper {
  static IconData getIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('ac') || lower.contains('appliance')) {
      return Icons.ac_unit_rounded;
    } else if (lower.contains('plumb')) {
      return Icons.plumbing_rounded;
    } else if (lower.contains('electr')) {
      return Icons.electrical_services_rounded;
    } else if (lower.contains('clean')) {
      return Icons.cleaning_services_rounded;
    } else if (lower.contains('paint')) {
      return Icons.format_paint_rounded;
    } else if (lower.contains('carpent')) {
      return Icons.handyman_rounded;
    }
    return Icons.build_circle_rounded;
  }

  static Color getColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('ac')) {
      return const Color(0xFF0284C7); // Sky blue
    } else if (lower.contains('plumb')) {
      return const Color(0xFF2563EB); // Blue
    } else if (lower.contains('electr')) {
      return const Color(0xFFD97706); // Amber
    } else if (lower.contains('clean')) {
      return const Color(0xFF10B981); // Emerald
    }
    return const Color(0xFF4F46E5); // Indigo
  }

  static Color getBgColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('ac')) {
      return const Color(0xFFE0F2FE);
    } else if (lower.contains('plumb')) {
      return const Color(0xFFEFF6FF);
    } else if (lower.contains('electr')) {
      return const Color(0xFFFFFBEB);
    } else if (lower.contains('clean')) {
      return const Color(0xFFECFDF5);
    }
    return const Color(0xFFEEF2FF);
  }
}

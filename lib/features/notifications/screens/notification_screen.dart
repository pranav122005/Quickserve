import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/app_notification.dart';
import '../../../models/user_role.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../../customer/presentation/screens/customer_tracking_screen.dart';
import '../controllers/notification_controller.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  static Future<void> showAsBottomSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const FractionallySizedBox(
        heightFactor: 0.85,
        child: NotificationScreen(),
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.agentAssigned:
        return Icons.person_pin_circle_rounded;
      case NotificationType.agentAccepted:
        return Icons.check_circle_rounded;
      case NotificationType.etaUpdated:
        return Icons.access_time_filled_rounded;
      case NotificationType.serviceStarted:
        return Icons.play_circle_fill_rounded;
      case NotificationType.serviceCompleted:
        return Icons.task_alt_rounded;
      case NotificationType.requestCancelled:
        return Icons.cancel_rounded;
      case NotificationType.newOffer:
        return Icons.local_offer_rounded;
      case NotificationType.requestAssigned:
        return Icons.assignment_ind_rounded;
      case NotificationType.newRequest:
        return Icons.notification_add_rounded;
      case NotificationType.general:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.agentAssigned:
      case NotificationType.requestAssigned:
      case NotificationType.serviceStarted:
        return const Color(0xFF2563EB);
      case NotificationType.agentAccepted:
      case NotificationType.serviceCompleted:
        return const Color(0xFF10B981);
      case NotificationType.etaUpdated:
        return const Color(0xFF059669);
      case NotificationType.requestCancelled:
        return const Color(0xFFEF4444);
      case NotificationType.newOffer:
        return const Color(0xFF6366F1);
      case NotificationType.newRequest:
        return const Color(0xFFF59E0B);
      case NotificationType.general:
        return const Color(0xFF64748B);
    }
  }

  void _handleNotificationTap(BuildContext context, WidgetRef ref, AppNotification notification) {
    // 1. Mark notification as read
    if (!notification.isRead) {
      ref.read(notificationControllerProvider.notifier).markAsRead(notification.id);
    }

    // Close bottom sheet if open
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // 2. Deep link based on user role and request_id
    if (notification.requestId != null && notification.requestId!.isNotEmpty) {
      final role = ref.read(currentUserRoleProvider);
      if (role == UserRole.customer) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => FractionallySizedBox(
            heightFactor: 0.9,
            child: CustomerTrackingScreen(requestId: notification.requestId!),
          ),
        );
      } else if (role == UserRole.agent) {
        context.go('/agent');
      } else if (role == UserRole.admin) {
        context.go('/admin');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationControllerProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (state.unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${state.unreadCount} NEW',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (state.unreadCount > 0)
                  TextButton(
                    onPressed: () {
                      ref.read(notificationControllerProvider.notifier).markAllAsRead();
                    },
                    child: const Text(
                      'Mark all as read',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
          ),

          // Content List
          Expanded(
            child: state.isLoading && state.notifications.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_off_rounded,
                                size: 40,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Notifications Yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Real-time status updates and job offers will appear here.',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref.read(notificationControllerProvider.notifier).refresh(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: state.notifications.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = state.notifications[index];
                            final icon = _getNotificationIcon(item.type);
                            final color = _getNotificationColor(item.type);

                            return InkWell(
                              onTap: () => _handleNotificationTap(context, ref, item),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: item.isRead ? Colors.white : const Color(0xFFF0F9FF),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: item.isRead ? const Color(0xFFE2E8F0) : const Color(0xFFBAE6FD),
                                    width: item.isRead ? 1 : 1.5,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(icon, color: color, size: 20),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.title,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                item.timeAgo,
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.body,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF334155),
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!item.isRead) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF2563EB),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

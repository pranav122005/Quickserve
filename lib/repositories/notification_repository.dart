import '../models/app_notification.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> getNotifications(String userId, {int limit = 50});
  Future<int> getUnreadCount(String userId);
  Future<bool> markAsRead(String notificationId);
  Future<bool> markAllAsRead(String userId);
  Future<AppNotification?> createNotification({
    required String userId,
    String? requestId,
    required NotificationType type,
    required String title,
    required String body,
  });
}

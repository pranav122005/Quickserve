import '../models/app_notification.dart';
import '../services/supabase_service.dart';
import 'notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final SupabaseService _supabaseService;

  NotificationRepositoryImpl(this._supabaseService);

  @override
  Future<List<AppNotification>> getNotifications(String userId, {int limit = 50}) async {
    try {
      final response = await _supabaseService.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      final list = (response as List)
          .map((item) => AppNotification.fromMap(item as Map<String, dynamic>))
          .toList();
      return list;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabaseService.client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _supabaseService.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> markAllAsRead(String userId) async {
    try {
      await _supabaseService.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AppNotification?> createNotification({
    required String userId,
    String? requestId,
    required NotificationType type,
    required String title,
    required String body,
  }) async {
    try {
      final data = <String, dynamic>{
        'user_id': userId,
        'request_id': requestId,
        'type': type.toDbString(),
        'title': title,
        'body': body,
        'is_read': false,
      };

      final response = await _supabaseService.client
          .from('notifications')
          .insert(data)
          .select()
          .single();

      return AppNotification.fromMap(response);
    } catch (_) {
      return null;
    }
  }
}

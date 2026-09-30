import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import '../../../models/app_notification.dart';
import '../../../features/auth/presentation/controllers/auth_providers.dart';

class NotificationState {
  final bool isLoading;
  final List<AppNotification> notifications;
  final int unreadCount;
  final String? errorMessage;

  const NotificationState({
    this.isLoading = false,
    this.notifications = const [],
    this.unreadCount = 0,
    this.errorMessage,
  });

  NotificationState copyWith({
    bool? isLoading,
    List<AppNotification>? notifications,
    int? unreadCount,
    String? errorMessage,
  }) {
    return NotificationState(
      isLoading: isLoading ?? this.isLoading,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      errorMessage: errorMessage,
    );
  }
}

class NotificationNotifier extends Notifier<NotificationState> {
  RealtimeChannel? _subscription;

  @override
  NotificationState build() {
    ref.onDispose(() {
      _subscription?.unsubscribe();
    });

    final user = ref.watch(authControllerProvider).user;
    if (user != null) {
      Future.microtask(() {
        initForUser(user.id);
      });
    }

    return const NotificationState();
  }

  Future<void> initForUser(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    await refresh(userId);

    // Subscribe to realtime notifications for the logged in user
    final realtime = ref.read(realtimeServiceProvider);
    _subscription?.unsubscribe();
    _subscription = realtime.subscribeToUserNotifications(
      userId: userId,
      onNotificationReceived: (notification) {
        // Prevent duplicate insertion
        final existingIdx = state.notifications.indexWhere((n) => n.id == notification.id);
        if (existingIdx != -1) {
          final updatedList = List<AppNotification>.from(state.notifications);
          updatedList[existingIdx] = notification;
          final unread = updatedList.where((n) => !n.isRead).length;
          state = state.copyWith(notifications: updatedList, unreadCount: unread);
        } else {
          final updatedList = [notification, ...state.notifications];
          final unread = updatedList.where((n) => !n.isRead).length;
          state = state.copyWith(notifications: updatedList, unreadCount: unread);
        }
      },
    );
  }

  Future<void> refresh([String? userId]) async {
    final uid = userId ?? ref.read(authControllerProvider).user?.id;
    if (uid == null) return;

    final repo = ref.read(notificationRepositoryProvider);
    final list = await repo.getNotifications(uid);
    final unread = list.where((n) => !n.isRead).length;

    state = state.copyWith(
      isLoading: false,
      notifications: list,
      unreadCount: unread,
      errorMessage: null,
    );
  }

  Future<void> markAsRead(String notificationId) async {
    final repo = ref.read(notificationRepositoryProvider);
    final success = await repo.markAsRead(notificationId);

    if (success) {
      final updatedList = state.notifications.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();

      final unread = updatedList.where((n) => !n.isRead).length;
      state = state.copyWith(notifications: updatedList, unreadCount: unread);
    }
  }

  Future<void> markAllAsRead() async {
    final uid = ref.read(authControllerProvider).user?.id;
    if (uid == null) return;

    final repo = ref.read(notificationRepositoryProvider);
    final success = await repo.markAllAsRead(uid);

    if (success) {
      final updatedList = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
      state = state.copyWith(notifications: updatedList, unreadCount: 0);
    }
  }
}

final notificationControllerProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(() {
  return NotificationNotifier();
});

import 'package:flutter_test/flutter_test.dart';
import 'package:quickserve/models/app_notification.dart';

void main() {
  group('AppNotification & NotificationType Unit Tests', () {
    test('1. NotificationType parses all types correctly with fallback', () {
      expect(NotificationType.fromString('agent_assigned'), equals(NotificationType.agentAssigned));
      expect(NotificationType.fromString('agent_accepted'), equals(NotificationType.agentAccepted));
      expect(NotificationType.fromString('eta_updated'), equals(NotificationType.etaUpdated));
      expect(NotificationType.fromString('service_started'), equals(NotificationType.serviceStarted));
      expect(NotificationType.fromString('service_completed'), equals(NotificationType.serviceCompleted));
      expect(NotificationType.fromString('request_cancelled'), equals(NotificationType.requestCancelled));
      expect(NotificationType.fromString('new_offer'), equals(NotificationType.newOffer));
      expect(NotificationType.fromString('request_assigned'), equals(NotificationType.requestAssigned));
      expect(NotificationType.fromString('new_request'), equals(NotificationType.newRequest));
      expect(NotificationType.fromString('unknown_type'), equals(NotificationType.general));
      expect(NotificationType.fromString(null), equals(NotificationType.general));
    });

    test('2. AppNotification.fromMap deserializes database map correctly', () {
      final now = DateTime.now();
      final map = {
        'id': 'notif-123',
        'user_id': 'user-456',
        'request_id': 'req-789',
        'type': 'agent_assigned',
        'title': 'Agent Assigned',
        'body': 'Service agent Rahul assigned to your request.',
        'is_read': false,
        'created_at': now.toIso8601String(),
      };

      final notif = AppNotification.fromMap(map);

      expect(notif.id, equals('notif-123'));
      expect(notif.userId, equals('user-456'));
      expect(notif.requestId, equals('req-789'));
      expect(notif.type, equals(NotificationType.agentAssigned));
      expect(notif.title, equals('Agent Assigned'));
      expect(notif.body, equals('Service agent Rahul assigned to your request.'));
      expect(notif.isRead, isFalse);
    });

    test('3. AppNotification.toMap serializes correctly for database persistence', () {
      final now = DateTime.now();
      final notif = AppNotification(
        id: 'notif-100',
        userId: 'user-200',
        requestId: 'req-300',
        type: NotificationType.etaUpdated,
        title: 'ETA Updated',
        body: 'Agent expected at 3:45 PM.',
        isRead: true,
        createdAt: now,
      );

      final map = notif.toMap();

      expect(map['id'], equals('notif-100'));
      expect(map['user_id'], equals('user-200'));
      expect(map['request_id'], equals('req-300'));
      expect(map['type'], equals('eta_updated'));
      expect(map['title'], equals('ETA Updated'));
      expect(map['body'], equals('Agent expected at 3:45 PM.'));
      expect(map['is_read'], isTrue);
    });

    test('4. copyWith updates read state cleanly', () {
      final notif = AppNotification(
        id: 'notif-1',
        userId: 'u-1',
        type: NotificationType.serviceStarted,
        title: 'Service Started',
        body: 'Service started',
        isRead: false,
        createdAt: DateTime.now(),
      );

      final updated = notif.copyWith(isRead: true);

      expect(notif.isRead, isFalse);
      expect(updated.isRead, isTrue);
      expect(updated.id, equals(notif.id));
    });

    test('5. timeAgo computes relative duration properly', () {
      final now = DateTime.now();
      final justNow = AppNotification(
        id: '1',
        userId: 'u',
        type: NotificationType.general,
        title: 'T',
        body: 'B',
        createdAt: now.subtract(const Duration(seconds: 10)),
      );

      final fiveMinAgo = AppNotification(
        id: '2',
        userId: 'u',
        type: NotificationType.general,
        title: 'T',
        body: 'B',
        createdAt: now.subtract(const Duration(minutes: 5)),
      );

      final twoHoursAgo = AppNotification(
        id: '3',
        userId: 'u',
        type: NotificationType.general,
        title: 'T',
        body: 'B',
        createdAt: now.subtract(const Duration(hours: 2)),
      );

      expect(justNow.timeAgo, equals('Just now'));
      expect(fiveMinAgo.timeAgo, equals('5 min ago'));
      expect(twoHoursAgo.timeAgo, equals('2 hrs ago'));
    });
  });
}

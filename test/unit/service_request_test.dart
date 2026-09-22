import 'package:flutter_test/flutter_test.dart';
import 'package:quickserve/models/service_request.dart';
import 'package:quickserve/core/constants/app_constants.dart';

void main() {
  group('ServiceRequest Model Tests', () {
    test('RequestPriority parses correctly and uses normal as fallback', () {
      expect(RequestPriority.fromString('low'), RequestPriority.low);
      expect(RequestPriority.fromString('normal'), RequestPriority.normal);
      expect(RequestPriority.fromString('high'), RequestPriority.high);
      expect(RequestPriority.fromString('urgent'), RequestPriority.urgent);

      // Verify "medium" or unrecognized values fallback safely to "normal"
      expect(RequestPriority.fromString('medium'), RequestPriority.normal);
      expect(RequestPriority.fromString(null), RequestPriority.normal);
      expect(RequestPriority.fromString('unknown'), RequestPriority.normal);
    });

    test('RequestStatus flags and helpers work properly', () {
      expect(RequestStatus.pending.isPending, isTrue);
      expect(RequestStatus.pending.canBeCancelledByCustomer, isTrue);

      expect(RequestStatus.assigned.isActive, isTrue);
      expect(RequestStatus.assigned.canBeCancelledByCustomer, isTrue);

      expect(RequestStatus.inProgress.isActive, isTrue);
      expect(RequestStatus.inProgress.canBeCancelledByCustomer, isFalse);

      expect(RequestStatus.completed.isCompleted, isTrue);
      expect(RequestStatus.completed.canBeCancelledByCustomer, isFalse);

      expect(RequestStatus.cancelled.isCancelled, isTrue);
      expect(RequestStatus.cancelled.canBeCancelledByCustomer, isFalse);
    });

    test('ServiceRequest.fromMap deserializes database fields accurately', () {
      final map = {
        DbColumns.id: 'req-1234-uuid',
        DbColumns.customerId: 'cust-5678-uuid',
        DbColumns.category: 'Cleaning',
        DbColumns.title: 'Deep clean kitchen',
        DbColumns.description: 'Please bring floor scrubber',
        DbColumns.serviceAddress: '123 Tech Park Road, Bengaluru',
        DbColumns.priority: 'urgent',
        DbColumns.status: 'pending',
        DbColumns.serviceLocation: 'POINT(77.5946 12.9716)',
        DbColumns.createdAt: '2026-09-20T10:00:00.000Z',
        DbColumns.updatedAt: '2026-09-20T10:30:00.000Z',
      };

      final req = ServiceRequest.fromMap(map);
      expect(req.id, 'req-1234-uuid');
      expect(req.customerId, 'cust-5678-uuid');
      expect(req.category, 'Cleaning');
      expect(req.title, 'Deep clean kitchen');
      expect(req.description, 'Please bring floor scrubber');
      expect(req.serviceAddress, '123 Tech Park Road, Bengaluru');
      expect(req.priority, RequestPriority.urgent);
      expect(req.status, RequestStatus.pending);
      expect(req.location, isNotNull);
      expect(req.location!.latitude, closeTo(12.9716, 0.0001));
      expect(req.location!.longitude, closeTo(77.5946, 0.0001));
      expect(req.createdAt, isNotNull);
      expect(req.updatedAt, isNotNull);
    });

    test('toMap formats fields properly without altering schema', () {
      final req = ServiceRequest(
        id: 'req-001',
        customerId: 'cust-001',
        category: 'Electrical',
        title: 'Fix circuit breaker',
        serviceAddress: '456 Residency Rd',
        priority: RequestPriority.high,
        status: RequestStatus.pending,
      );

      final map = req.toMap();
      expect(map[DbColumns.category], 'Electrical');
      expect(map[DbColumns.title], 'Fix circuit breaker');
      expect(map[DbColumns.priority], 'high');
      expect(map[DbColumns.status], 'pending');
    });

    test('formattedId produces REQ-YYYY-XXXXXX format matching assignment spec', () {
      final req = ServiceRequest(
        id: '12345678-abcd-1234-abcd-1234567890ab',
        customerId: 'cust-001',
        category: 'AC Servicing',
        title: 'AC gas recharge',
        serviceAddress: '123 MG Road',
        priority: RequestPriority.high,
        status: RequestStatus.pending,
        createdAt: DateTime(2026, 9, 21),
      );

      expect(req.formattedId, 'REQ-2026-123456');
      expect(RequestPriority.normal.displayName, 'Medium');
    });
  });
}

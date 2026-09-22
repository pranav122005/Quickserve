import 'package:flutter_test/flutter_test.dart';
import 'package:quickserve/core/utils/geo_utils.dart';
import 'package:quickserve/models/agent_location.dart';
import 'package:quickserve/models/service_request.dart';

void main() {
  group('Phase 4 Customer Mobile Tests', () {
    test('1. RequestPriority schema strictly avoids "medium" and parses correctly', () {
      expect(RequestPriority.fromString('low'), RequestPriority.low);
      expect(RequestPriority.fromString('normal'), RequestPriority.normal);
      expect(RequestPriority.fromString('high'), RequestPriority.high);
      expect(RequestPriority.fromString('urgent'), RequestPriority.urgent);

      // "medium" does not exist in schema, should fall back to normal
      expect(RequestPriority.fromString('medium'), RequestPriority.normal);
      expect(RequestPriority.fromString(null), RequestPriority.normal);
      expect(RequestPriority.fromString(''), RequestPriority.normal);
    });

    test('2. Coordinate validation strictly enforces [-90, 90] and [-180, 180]', () {
      expect(GeoUtils.isValidCoordinates(0.0, 0.0), isTrue);
      expect(GeoUtils.isValidCoordinates(90.0, 180.0), isTrue);
      expect(GeoUtils.isValidCoordinates(-90.0, -180.0), isTrue);
      expect(GeoUtils.isValidCoordinates(12.9716, 77.5946), isTrue);

      // Invalid boundaries
      expect(GeoUtils.isValidCoordinates(90.001, 77.0), isFalse);
      expect(GeoUtils.isValidCoordinates(-90.001, 77.0), isFalse);
      expect(GeoUtils.isValidCoordinates(12.0, 180.001), isFalse);
      expect(GeoUtils.isValidCoordinates(12.0, -180.001), isFalse);
    });

    test('3. PostGIS WKT formatting preserves POINT(longitude latitude) format', () {
      final wkt = GeoUtils.formatPointWkt(12.9716, 77.5946);
      expect(wkt, 'POINT(77.5946 12.9716)');

      expect(
        () => GeoUtils.formatPointWkt(95.0, 77.0),
        throwsArgumentError,
      );
    });

    test('4. Customer cancellation rules adhere strictly to backend lifecycle', () {
      // Allowed: pending, dispatching, assigned
      expect(RequestStatus.pending.canBeCancelledByCustomer, isTrue);
      expect(RequestStatus.dispatching.canBeCancelledByCustomer, isTrue);
      expect(RequestStatus.assigned.canBeCancelledByCustomer, isTrue);

      // Disallowed: inProgress, completed, cancelled
      expect(RequestStatus.inProgress.canBeCancelledByCustomer, isFalse);
      expect(RequestStatus.completed.canBeCancelledByCustomer, isFalse);
      expect(RequestStatus.cancelled.canBeCancelledByCustomer, isFalse);
    });

    test('5. Stale location detection flags locations older than 120s', () {
      final base = DateTime.parse('2026-09-20T12:00:00.000Z');

      final fresh = AgentLocation(
        agentId: 'agent-1',
        location: const GeoPoint(latitude: 12.9716, longitude: 77.5946),
        updatedAt: base.subtract(const Duration(seconds: 45)),
      );
      expect(fresh.isStale(thresholdSeconds: 120, referenceTime: base), isFalse);

      final stale = AgentLocation(
        agentId: 'agent-1',
        location: const GeoPoint(latitude: 12.9716, longitude: 77.5946),
        updatedAt: base.subtract(const Duration(seconds: 121)),
      );
      expect(stale.isStale(thresholdSeconds: 120, referenceTime: base), isTrue);
    });

    test('6. Active requests survive restart by correctly evaluating isActive flag', () {
      final activeStatuses = [
        RequestStatus.pending,
        RequestStatus.dispatching,
        RequestStatus.assigned,
        RequestStatus.inProgress,
      ];
      for (final s in activeStatuses) {
        expect(s.isActive, isTrue, reason: '$s should be active');
      }

      final terminalStatuses = [
        RequestStatus.completed,
        RequestStatus.cancelled,
      ];
      for (final s in terminalStatuses) {
        expect(s.isActive, isFalse, reason: '$s should not be active');
      }
    });

    test('7. ServiceRequest deserialization handles location and priority accurately', () {
      final map = {
        'id': 'req-123',
        'customer_id': 'cust-456',
        'category': 'Plumbing',
        'title': 'Kitchen sink issue',
        'description': 'Leak under cabinet',
        'service_address': '42 MG Road, Bengaluru',
        'priority': 'urgent',
        'status': 'assigned',
        'service_location': 'POINT(77.5946 12.9716)',
        'created_at': '2026-09-20T10:00:00.000Z',
      };

      final req = ServiceRequest.fromMap(map);
      expect(req.id, 'req-123');
      expect(req.priority, RequestPriority.urgent);
      expect(req.status, RequestStatus.assigned);
      expect(req.location, isNotNull);
      expect(req.location!.latitude, closeTo(12.9716, 0.0001));
      expect(req.location!.longitude, closeTo(77.5946, 0.0001));
    });
  });
}

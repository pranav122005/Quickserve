import 'package:flutter_test/flutter_test.dart';
import 'package:quickserve/models/service_assignment.dart';
import 'package:quickserve/core/constants/app_constants.dart';

void main() {
  group('ServiceAssignment Model Tests', () {
    test('AssignmentStatus contains exact allowed database enum values', () {
      final allowedDbValues = {'offered', 'accepted', 'rejected', 'cancelled', 'completed'};
      final currentDbValues = AssignmentStatus.values.map((s) => s.dbValue).toSet();

      expect(currentDbValues, allowedDbValues);
      // Explicitly confirm NO in_progress assignment status
      expect(currentDbValues.contains('in_progress'), isFalse);
    });

    test('AssignmentStatus.fromString parses correctly with fallback to offered', () {
      expect(AssignmentStatus.fromString('offered'), AssignmentStatus.offered);
      expect(AssignmentStatus.fromString('accepted'), AssignmentStatus.accepted);
      expect(AssignmentStatus.fromString('rejected'), AssignmentStatus.rejected);
      expect(AssignmentStatus.fromString('cancelled'), AssignmentStatus.cancelled);
      expect(AssignmentStatus.fromString('completed'), AssignmentStatus.completed);

      // Fallback for null or unknown
      expect(AssignmentStatus.fromString(null), AssignmentStatus.offered);
      expect(AssignmentStatus.fromString('invalid_status'), AssignmentStatus.offered);
    });

    test('ServiceAssignment deserializes from Map correctly', () {
      final map = {
        DbColumns.id: 'assign-uuid-1',
        DbColumns.requestId: 'req-uuid-1',
        DbColumns.agentId: 'agent-uuid-1',
        DbColumns.status: 'accepted',
        DbColumns.offeredAt: '2026-09-20T11:00:00.000Z',
        DbColumns.acceptedAt: '2026-09-20T11:05:00.000Z',
        DbColumns.rejectedAt: null,
        DbColumns.completedAt: null,
        DbColumns.createdAt: '2026-09-20T11:00:00.000Z',
      };

      final assignment = ServiceAssignment.fromMap(map);

      expect(assignment.id, 'assign-uuid-1');
      expect(assignment.requestId, 'req-uuid-1');
      expect(assignment.agentId, 'agent-uuid-1');
      expect(assignment.status, AssignmentStatus.accepted);
      expect(assignment.status.isAccepted, isTrue);
      expect(assignment.status.isCompleted, isFalse);
      expect(assignment.offeredAt, isNotNull);
      expect(assignment.acceptedAt, isNotNull);
      expect(assignment.rejectedAt, isNull);
    });

    test('ServiceAssignment serializes to Map with correct column names', () {
      final assignment = ServiceAssignment(
        id: 'assign-uuid-2',
        requestId: 'req-uuid-2',
        agentId: 'agent-uuid-2',
        status: AssignmentStatus.offered,
      );

      final map = assignment.toMap();

      expect(map[DbColumns.requestId], 'req-uuid-2');
      expect(map[DbColumns.agentId], 'agent-uuid-2');
      expect(map[DbColumns.status], 'offered');
    });
  });
}

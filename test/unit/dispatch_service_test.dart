import 'package:flutter_test/flutter_test.dart';
import 'package:quickserve/models/dispatch_result.dart';

void main() {
  group('DispatchResult Model Tests', () {
    test('fromMap parses successful offer response correctly', () {
      final map = {
        'success': true,
        'assignment_id': 'assign-uuid-456',
        'agent_id': 'agent-uuid-789',
        'distance_meters': 1420.5,
        'reason': null,
        'status': 'offered',
      };

      final result = DispatchResult.fromMap(map);
      expect(result.isSuccess, isTrue);
      expect(result.isOffered, isTrue);
      expect(result.assignmentId, 'assign-uuid-456');
      expect(result.agentId, 'agent-uuid-789');
      expect(result.distanceMeters, 1420.5);
      expect(result.message, contains('Dispatch successful'));
    });

    test('fromMap parses no available agents response correctly', () {
      final map = {
        'success': false,
        'assignment_id': null,
        'agent_id': null,
        'distance_meters': null,
        'reason': 'no_available_agent',
        'status': 'pending',
      };

      final result = DispatchResult.fromMap(map);
      expect(result.isSuccess, isFalse);
      expect(result.isOffered, isFalse);
      expect(result.isNoAgentAvailable, isTrue);
      expect(result.message, 'No available agents in service area.');
    });

    test('fromMap parses unauthorized response correctly', () {
      final map = {
        'success': false,
        'reason': 'unauthorized',
      };

      final result = DispatchResult.fromMap(map);
      expect(result.isSuccess, isFalse);
      expect(result.isUnauthorized, isTrue);
      expect(result.message, 'Unauthorized to dispatch this request.');
    });

    test('error factory constructs a clean failure result', () {
      final errorResult = DispatchResult.error('Database connection timed out');
      expect(errorResult.isSuccess, isFalse);
      expect(errorResult.reason, 'Database connection timed out');
      expect(errorResult.message, 'Database connection timed out');
    });

    test('toMap serializes properly', () {
      final result = const DispatchResult(
        success: true,
        assignmentId: 'assign-1',
        agentId: 'agent-1',
        distanceMeters: 500.0,
      );

      final map = result.toMap();
      expect(map['success'], isTrue);
      expect(map['assignment_id'], 'assign-1');
      expect(map['agent_id'], 'agent-1');
      expect(map['distance_meters'], 500.0);
    });
  });
}

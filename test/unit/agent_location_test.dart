import 'package:flutter_test/flutter_test.dart';
import 'package:quickserve/core/utils/geo_utils.dart';
import 'package:quickserve/models/agent_location.dart';

void main() {
  group('AgentLocation Model Tests', () {
    test('fromMap parses location and fields correctly', () {
      final map = {
        'agent_id': 'agent-uuid-123',
        'location': 'POINT(77.5946 12.9716)',
        'updated_at': '2026-09-20T12:00:00.000Z',
      };

      final agentLoc = AgentLocation.fromMap(map);
      expect(agentLoc.agentId, 'agent-uuid-123');
      expect(agentLoc.location.latitude, closeTo(12.9716, 0.0001));
      expect(agentLoc.location.longitude, closeTo(77.5946, 0.0001));
      expect(agentLoc.updatedAt, DateTime.parse('2026-09-20T12:00:00.000Z'));
    });

    test('toMap serializes properly to PostGIS WKT', () {
      final agentLoc = AgentLocation(
        agentId: 'agent-uuid-123',
        location: const GeoPoint(latitude: 12.9716, longitude: 77.5946),
        updatedAt: DateTime.parse('2026-09-20T12:00:00.000Z'),
      );

      final map = agentLoc.toMap();
      expect(map['agent_id'], 'agent-uuid-123');
      expect(map['location'], 'POINT(77.5946 12.9716)');
      expect(map['updated_at'], isNotNull);
    });

    test('isStale returns true when updatedAt is older than 120 seconds', () {
      final baseTime = DateTime.parse('2026-09-20T12:00:00.000Z');

      // 30 seconds old -> fresh
      final freshLoc = AgentLocation(
        agentId: 'agent-1',
        location: const GeoPoint(latitude: 12.0, longitude: 77.0),
        updatedAt: baseTime.subtract(const Duration(seconds: 30)),
      );
      expect(freshLoc.isStale(thresholdSeconds: 120, referenceTime: baseTime), isFalse);

      // Exactly 120 seconds old -> not stale (boundary: > threshold)
      final edgeLoc = AgentLocation(
        agentId: 'agent-1',
        location: const GeoPoint(latitude: 12.0, longitude: 77.0),
        updatedAt: baseTime.subtract(const Duration(seconds: 120)),
      );
      expect(edgeLoc.isStale(thresholdSeconds: 120, referenceTime: baseTime), isFalse);

      // 121 seconds old -> stale
      final staleLoc = AgentLocation(
        agentId: 'agent-1',
        location: const GeoPoint(latitude: 12.0, longitude: 77.0),
        updatedAt: baseTime.subtract(const Duration(seconds: 121)),
      );
      expect(staleLoc.isStale(thresholdSeconds: 120, referenceTime: baseTime), isTrue);

      // null updatedAt -> considered stale
      final nullTimeLoc = const AgentLocation(
        agentId: 'agent-1',
        location: GeoPoint(latitude: 12.0, longitude: 77.0),
        updatedAt: null,
      );
      expect(nullTimeLoc.isStale(thresholdSeconds: 120, referenceTime: baseTime), isTrue);
    });

    test('copyWith works correctly', () {
      final initial = AgentLocation(
        agentId: 'agent-1',
        location: const GeoPoint(latitude: 12.0, longitude: 77.0),
        updatedAt: DateTime.now(),
      );

      final updated = initial.copyWith(
        location: const GeoPoint(latitude: 13.0, longitude: 78.0),
      );

      expect(updated.agentId, 'agent-1');
      expect(updated.location.latitude, 13.0);
      expect(updated.location.longitude, 78.0);
    });
  });
}

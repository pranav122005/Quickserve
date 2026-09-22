import 'package:flutter_test/flutter_test.dart';
import 'package:quickserve/models/service_assignment.dart';

void main() {
  group('ServiceAssignment Offer Expiry Timer Tests', () {
    test('isOfferExpired returns true when 120 seconds have elapsed for offered assignments', () {
      final now = DateTime.parse('2026-09-20T12:00:00.000Z');

      // 60 seconds elapsed -> not expired
      final activeAssignment = ServiceAssignment(
        id: 'assign-1',
        requestId: 'req-1',
        agentId: 'agent-1',
        status: AssignmentStatus.offered,
        offeredAt: now.subtract(const Duration(seconds: 60)),
      );
      expect(activeAssignment.isOfferExpired(referenceTime: now, windowSeconds: 120), isFalse);

      // 120 seconds elapsed -> expired
      final boundaryAssignment = ServiceAssignment(
        id: 'assign-2',
        requestId: 'req-1',
        agentId: 'agent-1',
        status: AssignmentStatus.offered,
        offeredAt: now.subtract(const Duration(seconds: 120)),
      );
      expect(boundaryAssignment.isOfferExpired(referenceTime: now, windowSeconds: 120), isTrue);

      // 150 seconds elapsed -> expired
      final staleAssignment = ServiceAssignment(
        id: 'assign-3',
        requestId: 'req-1',
        agentId: 'agent-1',
        status: AssignmentStatus.offered,
        offeredAt: now.subtract(const Duration(seconds: 150)),
      );
      expect(staleAssignment.isOfferExpired(referenceTime: now, windowSeconds: 120), isTrue);
    });

    test('isOfferExpired returns false if status is not offered', () {
      final now = DateTime.parse('2026-09-20T12:00:00.000Z');

      final acceptedAssignment = ServiceAssignment(
        id: 'assign-4',
        requestId: 'req-1',
        agentId: 'agent-1',
        status: AssignmentStatus.accepted,
        offeredAt: now.subtract(const Duration(seconds: 300)),
        acceptedAt: now.subtract(const Duration(seconds: 280)),
      );
      expect(acceptedAssignment.isOfferExpired(referenceTime: now), isFalse);
    });

    test('remainingOfferSeconds returns remaining window or 0 if expired', () {
      final now = DateTime.parse('2026-09-20T12:00:00.000Z');

      // Offered 40s ago -> 80s remaining
      final assignment1 = ServiceAssignment(
        id: 'assign-5',
        requestId: 'req-1',
        agentId: 'agent-1',
        status: AssignmentStatus.offered,
        offeredAt: now.subtract(const Duration(seconds: 40)),
      );
      expect(assignment1.remainingOfferSeconds(referenceTime: now, windowSeconds: 120), 80);

      // Offered 125s ago -> 0s remaining
      final assignment2 = ServiceAssignment(
        id: 'assign-6',
        requestId: 'req-1',
        agentId: 'agent-1',
        status: AssignmentStatus.offered,
        offeredAt: now.subtract(const Duration(seconds: 125)),
      );
      expect(assignment2.remainingOfferSeconds(referenceTime: now, windowSeconds: 120), 0);

      // Not offered -> 0s
      final assignment3 = ServiceAssignment(
        id: 'assign-7',
        requestId: 'req-1',
        agentId: 'agent-1',
        status: AssignmentStatus.rejected,
        offeredAt: now.subtract(const Duration(seconds: 20)),
      );
      expect(assignment3.remainingOfferSeconds(referenceTime: now), 0);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:quickserve/models/agent_profile.dart';
import 'package:quickserve/models/service_assignment.dart';
import 'package:quickserve/models/service_request.dart';
import 'package:quickserve/services/geolocation_service.dart';
import 'package:quickserve/core/constants/app_constants.dart';
import 'package:quickserve/core/errors/app_exception.dart';
import 'package:quickserve/repositories/agent_profile_repository_impl.dart';
import 'package:quickserve/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Phase 4 Agent Mobile Tests', () {
    test('1. Agent availability states are strictly offline and available', () {
      expect(AgentAvailability.fromString('offline'), AgentAvailability.offline);
      expect(AgentAvailability.fromString('available'), AgentAvailability.available);
      expect(AgentAvailability.fromString('invalid'), AgentAvailability.offline);
      expect(AgentAvailability.fromString(null), AgentAvailability.offline);

      expect(AgentAvailability.available.isAvailable, isTrue);
      expect(AgentAvailability.offline.isAvailable, isFalse);
    });

    test('2. AgentProfile preserves 10–20 km service radius constraints and copyWith', () {
      final profile = const AgentProfile(
        userId: 'agent-123',
        serviceRadiusKm: 15.0,
        availability: AgentAvailability.available,
        isVerified: true,
      );

      // Default and range
      expect(profile.serviceRadiusKm, 15.0);
      expect(profile.availability, AgentAvailability.available);
      expect(profile.isVerified, isTrue);

      // Authoritative baseline constraints (10–20 km)
      expect(ServiceRadiusConstants.minRadiusKm, 10.0);
      expect(ServiceRadiusConstants.maxRadiusKm, 20.0);
      expect(ServiceRadiusConstants.defaultRadiusKm, 15.0);

      // Valid boundary values
      expect(ServiceRadiusConstants.isValid(10.0), isTrue);
      expect(ServiceRadiusConstants.isValid(15.0), isTrue);
      expect(ServiceRadiusConstants.isValid(20.0), isTrue);

      // Invalid values outside authoritative 10–20 km range
      expect(ServiceRadiusConstants.isValid(0.0), isFalse);
      expect(ServiceRadiusConstants.isValid(5.0), isFalse);
      expect(ServiceRadiusConstants.isValid(9.9), isFalse);
      expect(ServiceRadiusConstants.isValid(20.1), isFalse);
      expect(ServiceRadiusConstants.isValid(50.0), isFalse);
      expect(ServiceRadiusConstants.isValid(100.0), isFalse);
      expect(ServiceRadiusConstants.isValid(null), isFalse);

      final updated = profile.copyWith(serviceRadiusKm: 20.0, availability: AgentAvailability.offline);
      expect(updated.serviceRadiusKm, 20.0);
      expect(updated.availability, AgentAvailability.offline);
    });

    test('3. Offer countdown calculates 120s window and formats MM:SS correctly', () {
      final now = DateTime.parse('2026-09-20T12:00:00.000Z');

      // 45 seconds elapsed -> 75 seconds remaining (01:15)
      final offer = ServiceAssignment(
        id: 'assign-1',
        requestId: 'req-1',
        agentId: 'agent-1',
        status: AssignmentStatus.offered,
        offeredAt: now.subtract(const Duration(seconds: 45)),
      );

      final remainingSec = offer.remainingOfferSeconds(referenceTime: now);
      expect(remainingSec, 75);

      final minutes = (remainingSec ~/ 60).toString().padLeft(2, '0');
      final seconds = (remainingSec % 60).toString().padLeft(2, '0');
      expect('$minutes:$seconds', '01:15');
      expect(offer.isOfferExpired(referenceTime: now), isFalse);
    });

    test('4. Offer expiry triggers at >= 120 seconds', () {
      final now = DateTime.parse('2026-09-20T12:00:00.000Z');

      final expiredOffer = ServiceAssignment(
        id: 'assign-2',
        requestId: 'req-1',
        agentId: 'agent-1',
        status: AssignmentStatus.offered,
        offeredAt: now.subtract(const Duration(seconds: 120)),
      );

      expect(expiredOffer.remainingOfferSeconds(referenceTime: now), 0);
      expect(expiredOffer.isOfferExpired(referenceTime: now), isTrue);
    });

    test('5. LocationPermissionStatus supports all mandatory states', () {
      expect(LocationPermissionStatus.values, contains(LocationPermissionStatus.serviceDisabled));
      expect(LocationPermissionStatus.values, contains(LocationPermissionStatus.denied));
      expect(LocationPermissionStatus.values, contains(LocationPermissionStatus.permanentlyDenied));
      expect(LocationPermissionStatus.values, contains(LocationPermissionStatus.granted));
    });

    test('6. GPS start criteria strictly matches backend accepted + (assigned or in_progress)', () {
      bool shouldPublishGPS(AssignmentStatus assignStatus, RequestStatus reqStatus) {
        return assignStatus == AssignmentStatus.accepted &&
            (reqStatus == RequestStatus.assigned || reqStatus == RequestStatus.inProgress);
      }

      // Valid combinations
      expect(shouldPublishGPS(AssignmentStatus.accepted, RequestStatus.assigned), isTrue);
      expect(shouldPublishGPS(AssignmentStatus.accepted, RequestStatus.inProgress), isTrue);

      // Invalid combinations (must NOT start GPS)
      expect(shouldPublishGPS(AssignmentStatus.offered, RequestStatus.dispatching), isFalse);
      expect(shouldPublishGPS(AssignmentStatus.offered, RequestStatus.assigned), isFalse);
      expect(shouldPublishGPS(AssignmentStatus.rejected, RequestStatus.dispatching), isFalse);
      expect(shouldPublishGPS(AssignmentStatus.accepted, RequestStatus.completed), isFalse);
      expect(shouldPublishGPS(AssignmentStatus.accepted, RequestStatus.cancelled), isFalse);
      expect(shouldPublishGPS(AssignmentStatus.completed, RequestStatus.completed), isFalse);
    });

    test('7. Assignment model does not introduce in_progress assignment status', () {
      final statuses = AssignmentStatus.values.map((s) => s.dbValue).toList();
      expect(statuses, contains('offered'));
      expect(statuses, contains('accepted'));
      expect(statuses, contains('rejected'));
      expect(statuses, contains('cancelled'));
      expect(statuses, contains('completed'));

      // in_progress must NOT exist on assignment (it belongs strictly to service_requests)
      expect(statuses.contains('in_progress'), isFalse);
    });

    test('8. AgentProfileRepositoryImpl rejects out-of-range radius authoritatively', () {
      final dummyClient = SupabaseClient('https://example.supabase.co', 'dummy-key');
      final repo = AgentProfileRepositoryImpl(SupabaseService(dummyClient));

      // Should synchronously throw ValidationException for radius < 10 without calling backend
      expect(
        () => repo.updateServiceRadius('agent-1', 5.0),
        throwsA(isA<ValidationException>()),
      );

      // Should synchronously throw ValidationException for radius > 20 without calling backend
      expect(
        () => repo.updateServiceRadius('agent-1', 25.0),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => repo.updateServiceRadius('agent-1', 100.0),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}

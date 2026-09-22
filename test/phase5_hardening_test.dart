import 'package:flutter_test/flutter_test.dart';
import 'package:quickserve/core/constants/app_constants.dart';
import 'package:quickserve/core/errors/app_exception.dart';
import 'package:quickserve/app/router.dart';
import 'package:quickserve/features/auth/presentation/controllers/auth_state.dart';
import 'package:quickserve/models/user_profile.dart';
import 'package:quickserve/models/user_role.dart';
import 'package:quickserve/models/service_request.dart';
import 'package:quickserve/models/service_assignment.dart';
import 'package:quickserve/models/dispatch_result.dart';
import 'package:quickserve/models/payment_record.dart';
import 'package:quickserve/repositories/payment_repository_impl.dart';
import 'package:quickserve/repositories/agent_profile_repository_impl.dart';
import 'package:quickserve/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final dummyClient = SupabaseClient('https://example.supabase.co', 'dummy-key');

  group('Phase 5 Hardening & Security Tests', () {
    test('1. PaymentRepository validates amount must be greater than zero', () async {
      final repo = PaymentRepositoryImpl(SupabaseService(dummyClient));

      expect(
        () => repo.recordPayment(
          requestId: 'req-1',
          customerId: 'cust-1',
          agentId: 'agent-1',
          amount: 0.0,
          method: PaymentMethod.cash,
        ),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('must be greater than zero'),
        )),
      );

      expect(
        () => repo.recordPayment(
          requestId: 'req-1',
          customerId: 'cust-1',
          agentId: 'agent-1',
          amount: -50.0,
          method: PaymentMethod.upi,
        ),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('must be greater than zero'),
        )),
      );
    });

    test('2. Authoritative Agent Radius enforces strict 10-20 km bounds', () async {
      final repo = AgentProfileRepositoryImpl(SupabaseService(dummyClient));

      // Too low (< 10)
      expect(
        () => repo.updateServiceRadius('agent-1', 9.9),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('between 10 and 20 km'),
        )),
      );

      // Too high (> 20)
      expect(
        () => repo.updateServiceRadius('agent-1', 20.1),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('between 10 and 20 km'),
        )),
      );
    });

    test('3. RouterGuard protects deep-link routes against unauthenticated access', () {
      final unauthState = AppAuthState.unauthenticated();

      // Deep link to customer tracking
      final redirect1 = computeRouteRedirect(
        authState: unauthState,
        currentPath: '/customer/tracking/req-123',
      );
      expect(redirect1, equals(AppRoutes.login));

      // Deep link to agent dashboard
      final redirect2 = computeRouteRedirect(
        authState: unauthState,
        currentPath: '/agent',
      );
      expect(redirect2, equals(AppRoutes.login));

      // Deep link to admin dashboard
      final redirect3 = computeRouteRedirect(
        authState: unauthState,
        currentPath: '/admin',
      );
      expect(redirect3, equals(AppRoutes.login));
    });

    test('4. RouterGuard prevents privilege escalation across all roles', () {
      final customerAuth = AppAuthState(
        status: AuthStatus.authenticated,
        profile: const UserProfile(
          id: 'user-1',
          fullName: 'Customer One',
          role: UserRole.customer,
        ),
      );

      // Customer trying to access agent or admin is blocked and redirected to customer home
      expect(
        computeRouteRedirect(authState: customerAuth, currentPath: '/agent'),
        equals(AppRoutes.customer),
      );
      expect(
        computeRouteRedirect(authState: customerAuth, currentPath: '/admin'),
        equals(AppRoutes.customer),
      );

      final agentAuth = AppAuthState(
        status: AuthStatus.authenticated,
        profile: const UserProfile(
          id: 'user-2',
          fullName: 'Agent One',
          role: UserRole.agent,
        ),
      );

      // Agent trying to access customer or admin is blocked
      expect(
        computeRouteRedirect(authState: agentAuth, currentPath: '/customer'),
        equals(AppRoutes.agent),
      );
      expect(
        computeRouteRedirect(authState: agentAuth, currentPath: '/admin'),
        equals(AppRoutes.agent),
      );

      final adminAuth = AppAuthState(
        status: AuthStatus.authenticated,
        profile: const UserProfile(
          id: 'user-3',
          fullName: 'Admin One',
          role: UserRole.admin,
        ),
      );

      // Admin trying to access customer or agent routes is redirected to admin home
      expect(
        computeRouteRedirect(authState: adminAuth, currentPath: '/customer'),
        equals(AppRoutes.admin),
      );
      expect(
        computeRouteRedirect(authState: adminAuth, currentPath: '/agent'),
        equals(AppRoutes.admin),
      );
    });

    test('5. Location Privacy: active tracking states strictly evaluated', () {
      // Customer can ONLY track when assignment is accepted AND request is assigned or in_progress
      bool canCustomerViewAgentLocation({
        required AssignmentStatus assignmentStatus,
        required RequestStatus requestStatus,
      }) {
        return assignmentStatus.isAccepted &&
            (requestStatus.isAssigned || requestStatus.isInProgress);
      }

      // Valid tracking conditions:
      expect(
        canCustomerViewAgentLocation(
          assignmentStatus: AssignmentStatus.accepted,
          requestStatus: RequestStatus.assigned,
        ),
        isTrue,
      );
      expect(
        canCustomerViewAgentLocation(
          assignmentStatus: AssignmentStatus.accepted,
          requestStatus: RequestStatus.inProgress,
        ),
        isTrue,
      );

      // Privacy violations (must NOT show location):
      // Offer pending but not yet accepted
      expect(
        canCustomerViewAgentLocation(
          assignmentStatus: AssignmentStatus.offered,
          requestStatus: RequestStatus.dispatching,
        ),
        isFalse,
      );
      // Service completed
      expect(
        canCustomerViewAgentLocation(
          assignmentStatus: AssignmentStatus.completed,
          requestStatus: RequestStatus.completed,
        ),
        isFalse,
      );
      // Request cancelled
      expect(
        canCustomerViewAgentLocation(
          assignmentStatus: AssignmentStatus.cancelled,
          requestStatus: RequestStatus.cancelled,
        ),
        isFalse,
      );
      // Assignment rejected
      expect(
        canCustomerViewAgentLocation(
          assignmentStatus: AssignmentStatus.rejected,
          requestStatus: RequestStatus.dispatching,
        ),
        isFalse,
      );
    });

    test('6. Dispatch result parsing handles both success and failure cases', () {
      final successJson = {
        'success': true,
        'assignment_id': 'asgn-100',
        'agent_id': 'agent-200',
        'distance_meters': 1420.5,
      };
      final successResult = DispatchResult.fromMap(successJson);
      expect(successResult.success, isTrue);
      expect(successResult.assignmentId, equals('asgn-100'));
      expect(successResult.agentId, equals('agent-200'));
      expect(successResult.distanceMeters, equals(1420.5));

      final failureJson = {
        'success': false,
        'reason': 'no_available_agent',
      };
      final failureResult = DispatchResult.fromMap(failureJson);
      expect(failureResult.success, isFalse);
      expect(failureResult.reason, equals('no_available_agent'));
      expect(failureResult.assignmentId, isNull);
    });

    test('7. 120-second offer expiry accurately calculates remaining window', () {
      final now = DateTime.now();
      
      // Offer 60s old (60s remaining)
      final activeOffer = ServiceAssignment(
        id: 'asgn-1',
        requestId: 'req-1',
        agentId: 'agent-1',
        status: AssignmentStatus.offered,
        offeredAt: now.subtract(const Duration(seconds: 60)),
      );
      expect(activeOffer.isOfferExpired(), isFalse);
      expect(activeOffer.remainingOfferSeconds(), inInclusiveRange(58, 60));

      // Offer 121s old (expired)
      final expiredOffer = ServiceAssignment(
        id: 'asgn-2',
        requestId: 'req-2',
        agentId: 'agent-1',
        status: AssignmentStatus.offered,
        offeredAt: now.subtract(const Duration(seconds: 121)),
      );
      expect(expiredOffer.isOfferExpired(), isTrue);
      expect(expiredOffer.remainingOfferSeconds(), equals(0));
    });
  });
}

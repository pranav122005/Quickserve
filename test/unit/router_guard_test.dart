import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quickserve/app/router.dart';
import 'package:quickserve/core/constants/app_constants.dart';
import 'package:quickserve/features/auth/presentation/controllers/auth_state.dart';
import 'package:quickserve/models/user_profile.dart';
import 'package:quickserve/models/user_role.dart';

void main() {
  group('Router Guard Tests', () {
    const dummyUser = User(
      id: 'user-123',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01',
    );

    UserProfile createProfile(UserRole role) {
      return UserProfile(
        id: 'user-123',
        fullName: 'Test User',
        role: role,
      );
    }

    test('initial auth state redirects non-root paths to root splash', () {
      final initial = AppAuthState.initial();
      expect(
        computeRouteRedirect(authState: initial, currentPath: AppRoutes.login),
        AppRoutes.root,
      );
      expect(
        computeRouteRedirect(authState: initial, currentPath: AppRoutes.customer),
        AppRoutes.root,
      );
      expect(
        computeRouteRedirect(authState: initial, currentPath: AppRoutes.root),
        isNull,
      );
    });

    test('unauthenticated user is allowed on /login and /register', () {
      final unauth = AppAuthState.unauthenticated();
      expect(
        computeRouteRedirect(authState: unauth, currentPath: AppRoutes.login),
        isNull,
      );
      expect(
        computeRouteRedirect(authState: unauth, currentPath: AppRoutes.register),
        isNull,
      );
    });

    test('unauthenticated user is redirected to /login on protected routes', () {
      final unauth = AppAuthState.unauthenticated();
      expect(
        computeRouteRedirect(authState: unauth, currentPath: AppRoutes.customer),
        AppRoutes.login,
      );
      expect(
        computeRouteRedirect(authState: unauth, currentPath: AppRoutes.agent),
        AppRoutes.login,
      );
      expect(
        computeRouteRedirect(authState: unauth, currentPath: AppRoutes.admin),
        AppRoutes.login,
      );
    });

    test('profileError state redirects to /unauthorized', () {
      final profileErr = AppAuthState.profileError('Profile missing');
      expect(
        computeRouteRedirect(authState: profileErr, currentPath: AppRoutes.customer),
        AppRoutes.unauthorized,
      );
      expect(
        computeRouteRedirect(authState: profileErr, currentPath: AppRoutes.unauthorized),
        isNull,
      );
    });

    test('Customer role routes correctly to /customer from auth/splash paths', () {
      final customerState = AppAuthState.authenticated(
        user: dummyUser,
        profile: createProfile(UserRole.customer),
      );

      expect(
        computeRouteRedirect(authState: customerState, currentPath: AppRoutes.login),
        AppRoutes.customer,
      );
      expect(
        computeRouteRedirect(authState: customerState, currentPath: AppRoutes.register),
        AppRoutes.customer,
      );
      expect(
        computeRouteRedirect(authState: customerState, currentPath: AppRoutes.root),
        AppRoutes.customer,
      );
    });

    test('Customer cannot access /agent or /admin and is blocked', () {
      final customerState = AppAuthState.authenticated(
        user: dummyUser,
        profile: createProfile(UserRole.customer),
      );

      expect(
        computeRouteRedirect(authState: customerState, currentPath: AppRoutes.agent),
        AppRoutes.customer,
      );
      expect(
        computeRouteRedirect(authState: customerState, currentPath: AppRoutes.admin),
        AppRoutes.customer,
      );
      expect(
        computeRouteRedirect(authState: customerState, currentPath: AppRoutes.customer),
        isNull,
      );
    });

    test('Agent cannot access /customer or /admin and is blocked', () {
      final agentState = AppAuthState.authenticated(
        user: dummyUser,
        profile: createProfile(UserRole.agent),
      );

      expect(
        computeRouteRedirect(authState: agentState, currentPath: AppRoutes.customer),
        AppRoutes.agent,
      );
      expect(
        computeRouteRedirect(authState: agentState, currentPath: AppRoutes.admin),
        AppRoutes.agent,
      );
      expect(
        computeRouteRedirect(authState: agentState, currentPath: AppRoutes.agent),
        isNull,
      );
    });

    test('Admin cannot access /customer or /agent and is blocked', () {
      final adminState = AppAuthState.authenticated(
        user: dummyUser,
        profile: createProfile(UserRole.admin),
      );

      expect(
        computeRouteRedirect(authState: adminState, currentPath: AppRoutes.customer),
        AppRoutes.admin,
      );
      expect(
        computeRouteRedirect(authState: adminState, currentPath: AppRoutes.agent),
        AppRoutes.admin,
      );
      expect(
        computeRouteRedirect(authState: adminState, currentPath: AppRoutes.admin),
        isNull,
      );
    });
  });
}

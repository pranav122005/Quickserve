import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quickserve/features/auth/presentation/controllers/auth_state.dart';
import 'package:quickserve/models/user_profile.dart';
import 'package:quickserve/models/user_role.dart';

void main() {
  group('AppAuthState Tests', () {
    const dummyUser = User(
      id: 'test-user-id',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01',
    );

    const dummyProfile = UserProfile(
      id: 'test-user-id',
      fullName: 'Alice Customer',
      role: UserRole.customer,
    );

    test('initial state has correct defaults', () {
      final state = AppAuthState.initial();
      expect(state.status, AuthStatus.initial);
      expect(state.isInitial, isTrue);
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.role, isNull);
    });

    test('loading state reflects isLoading', () {
      final state = AppAuthState.loading(dummyUser);
      expect(state.status, AuthStatus.loading);
      expect(state.isLoading, isTrue);
      expect(state.user, dummyUser);
    });

    test('authenticated state exposes profile, user, and role', () {
      final state = AppAuthState.authenticated(
        user: dummyUser,
        profile: dummyProfile,
      );

      expect(state.status, AuthStatus.authenticated);
      expect(state.isAuthenticated, isTrue);
      expect(state.user, dummyUser);
      expect(state.profile, dummyProfile);
      expect(state.role, UserRole.customer);
    });

    test('unauthenticated state reflects not authenticated', () {
      final state = AppAuthState.unauthenticated();
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.isAuthenticated, isFalse);
      expect(state.profile, isNull);
    });

    test('error and profileError states contain messages', () {
      final errorState = AppAuthState.error('Network failure');
      expect(errorState.hasError, isTrue);
      expect(errorState.errorMessage, 'Network failure');

      final profileErrState = AppAuthState.profileError('Profile not found');
      expect(profileErrState.hasProfileError, isTrue);
      expect(profileErrState.errorMessage, 'Profile not found');
    });

    test('copyWith properly updates fields', () {
      final initial = AppAuthState.unauthenticated();
      final updated = initial.copyWith(
        status: AuthStatus.loading,
        errorMessage: 'Custom message',
      );

      expect(updated.status, AuthStatus.loading);
      expect(updated.errorMessage, 'Custom message');
    });
  });
}

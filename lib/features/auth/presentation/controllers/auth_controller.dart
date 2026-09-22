import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'auth_state.dart';
import 'auth_providers.dart';
import '../../../../repositories/auth_repository.dart';
import '../../../../repositories/profile_repository.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../services/audit_service.dart';

/// Manages authentication state, user session restoration, and profile loading.
class AuthController extends Notifier<AppAuthState> {
  AuthRepository get _authRepository => ref.read(authRepositoryProvider);
  ProfileRepository get _profileRepository => ref.read(profileRepositoryProvider);
  StreamSubscription<supa.AuthState>? _authSubscription;

  @override
  AppAuthState build() {
    _init();
    return const AppAuthState(status: AuthStatus.initial);
  }

  void _init() {
    _authSubscription = _authRepository.authStateChanges.listen((event) {
      final session = event.session;
      if (session != null && session.user.id.isNotEmpty) {
        if (state.user?.id != session.user.id || !state.isAuthenticated) {
          _loadUserProfile(session.user);
        }
      } else {
        if (!state.isInitial && state.status != AuthStatus.unauthenticated) {
          state = AppAuthState.unauthenticated();
        }
      }
    });

    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    // Check for existing active session on startup asynchronously
    Future.microtask(() {
      final currentUser = _authRepository.currentUser;
      if (currentUser != null) {
        _loadUserProfile(currentUser);
      } else {
        state = AppAuthState.unauthenticated();
      }
    });
  }

  Future<void> _loadUserProfile(supa.User user) async {
    state = AppAuthState.loading(user);
    try {
      final profile = await _profileRepository.getProfile(user.id);
      state = AppAuthState.authenticated(user: user, profile: profile);
    } on InvalidRoleException catch (e) {
      state = AppAuthState.profileError(e.message, user: user);
    } on ProfileNotFoundException catch (e) {
      state = AppAuthState.profileError(e.message, user: user);
    } catch (e) {
      final message = ErrorHandler.getUserMessage(e);
      state = AppAuthState.profileError(message, user: user);
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = AppAuthState.loading();
    try {
      final response = await _authRepository.signInWithEmail(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        state = AppAuthState.error('Authentication failed: no user returned.');
        return false;
      }

      await _loadUserProfile(user);
      if (state.isAuthenticated) {
        ref.read(auditServiceProvider).logLoginSuccess(
          user.id,
          email: user.email,
          role: state.profile?.role.dbValue,
        );
      }
      return state.isAuthenticated;
    } catch (e) {
      final userMessage = ErrorHandler.getUserMessage(e);
      state = AppAuthState.error(userMessage);
      return false;
    }
  }

  Future<bool> resetPassword({required String email}) async {
    try {
      await _authRepository.resetPassword(email: email);
      return true;
    } catch (e) {
      final userMessage = ErrorHandler.getUserMessage(e);
      state = AppAuthState.error(userMessage);
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    state = AppAuthState.loading();
    try {
      final response = await _authRepository.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );

      final user = response.user;
      if (user == null) {
        state = AppAuthState.error('Registration failed: no user returned.');
        return false;
      }

      if (response.session != null) {
        await _loadUserProfile(user);
        return state.isAuthenticated;
      } else {
        // Email confirmation is required by Supabase backend settings
        state = AppAuthState.pendingConfirmation(user);
        return true;
      }
    } catch (e) {
      final userMessage = ErrorHandler.getUserMessage(e);
      state = AppAuthState.error(userMessage);
      return false;
    }
  }

  Future<void> signOut() async {
    state = AppAuthState.loading();
    try {
      await _authRepository.signOut();
      state = AppAuthState.unauthenticated();
    } catch (e) {
      final userMessage = ErrorHandler.getUserMessage(e);
      state = AppAuthState.error(userMessage);
    }
  }

  Future<void> retryProfileLoad() async {
    final user = state.user ?? _authRepository.currentUser;
    if (user != null) {
      await _loadUserProfile(user);
    } else {
      state = AppAuthState.unauthenticated();
    }
  }
}

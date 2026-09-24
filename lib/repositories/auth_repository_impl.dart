import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_repository.dart';
import '../models/user_role.dart';
import '../services/supabase_service.dart';

/// Concrete implementation of [AuthRepository] backed by Supabase Auth.
class AuthRepositoryImpl implements AuthRepository {
  final SupabaseService _supabaseService;

  AuthRepositoryImpl(this._supabaseService);

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _supabaseService.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole requestedRole,
    String? phone,
  }) async {
    // Only pass standard user metadata (full name, optional phone). Role is forced server-side.
    final data = <String, dynamic>{
      'full_name': fullName.trim(),
      'requested_role': requestedRole == UserRole.agent ? 'agent' : 'customer',
    };
    if (phone != null && phone.trim().isNotEmpty) {
      data['phone'] = phone.trim();
    }

    return await _supabaseService.auth.signUp(
      email: email.trim(),
      password: password,
      data: data,
    );
  }

  @override
  Future<bool> signInWithOAuthGoogle({UserRole requestedRole = UserRole.customer}) async {
    return await _supabaseService.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'io.supabase.quickserve://login-callback',
      queryParams: {
        'requested_role': requestedRole == UserRole.agent ? 'agent' : 'customer',
      },
    );
  }

  @override
  Future<void> signOut() async {
    await _supabaseService.auth.signOut();
  }

  @override
  Future<void> resetPassword({required String email}) async {
    await _supabaseService.auth.resetPasswordForEmail(email.trim());
  }

  @override
  Stream<AuthState> get authStateChanges => _supabaseService.authStateChanges;

  @override
  User? get currentUser => _supabaseService.currentUser;

  @override
  Session? get currentSession => _supabaseService.currentSession;
}

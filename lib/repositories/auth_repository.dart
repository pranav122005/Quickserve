import 'package:supabase_flutter/supabase_flutter.dart';

/// Contract for authentication operations in QuickServe.
abstract class AuthRepository {
  /// Signs in a user using email and password.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  });

  /// Registers a new user account.
  /// 
  /// Only standard profile metadata (full name, optional phone) is submitted.
  /// Role assignment is strictly governed by the database trigger.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  });

  /// Signs out the currently authenticated user.
  Future<void> signOut();

  /// Stream of Supabase authentication state changes.
  Stream<AuthState> get authStateChanges;

  /// The currently authenticated Supabase user, if any.
  User? get currentUser;

  /// The current active session, if any.
  Session? get currentSession;
}

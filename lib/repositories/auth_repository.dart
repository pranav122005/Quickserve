import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';

/// Contract for authentication operations in QuickServe.
abstract class AuthRepository {
  /// Signs in a user using email and password.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  });

  /// Registers a new user account.
  /// 
  /// Only customer and agent signup requests are allowed. Admins are provisioned
  /// manually in the database and can never be selected by the client.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole requestedRole,
    String? phone,
  });

  /// Signs out the currently authenticated user.
  Future<void> signOut();

  /// Sends a password reset email to the provided email address.
  Future<void> resetPassword({required String email});

  /// Stream of Supabase authentication state changes.
  Stream<AuthState> get authStateChanges;

  /// The currently authenticated Supabase user, if any.
  User? get currentUser;

  /// The current active session, if any.
  Session? get currentSession;
}

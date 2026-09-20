import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps Supabase client access for dependency injection and testing.
class SupabaseService {
  final SupabaseClient _client;

  SupabaseService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  SupabaseClient get client => _client;
  GoTrueClient get auth => _client.auth;
  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}

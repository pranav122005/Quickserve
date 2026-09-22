import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'app_exception.dart';
import '../../services/audit_service.dart';

/// Translates technical or database exceptions into clean, user-friendly messages.
class ErrorHandler {
  static String getUserMessage(Object error) {
    if (error is AppException) {
      return error.message;
    }

    if (error is supa.AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials') || msg.contains('invalid grant')) {
        return 'Incorrect email or password. Please try again.';
      }
      if (msg.contains('user already registered') || msg.contains('already exists')) {
        return 'An account with this email address already exists.';
      }
      if (msg.contains('email not confirmed')) {
        return 'Please verify your email address before signing in.';
      }
      if (msg.contains('password')) {
        return 'Password does not meet security requirements.';
      }
      return error.message;
    }

    if (error is supa.PostgrestException) {
      AuditService().logDatabaseError('database_query', error.message, context: error.code);
      // Map Postgrest codes safely without exposing raw SQL errors
      if (error.code == '42501' || error.message.contains('permission denied')) {
        AuditService().logAuthorizationFailed(reason: 'database_permission_denied_42501');
        return 'You do not have permission to view or modify this data.';
      }
      if (error.code == 'PGRST116') {
        return 'The requested record was not found.';
      }
      return 'Unable to process your request. Please try again.';
    }

    final str = error.toString().toLowerCase();
    if (str.contains('socketexception') ||
        str.contains('network') ||
        str.contains('failed to connect') ||
        str.contains('clientexception')) {
      return 'Unable to reach the server. Please check your internet connection.';
    }

    return 'An unexpected error occurred. Please try again.';
  }
}

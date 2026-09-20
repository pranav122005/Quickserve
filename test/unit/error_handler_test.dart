import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:quickserve/core/errors/app_exception.dart';
import 'package:quickserve/core/errors/error_handler.dart';

void main() {
  group('ErrorHandler Tests', () {
    test('returns custom message for AppException', () {
      const exception = ProfileNotFoundException('Custom profile error');
      expect(ErrorHandler.getUserMessage(exception), 'Custom profile error');
    });

    test('maps invalid login credentials into friendly message', () {
      const authEx = supa.AuthException('Invalid login credentials');
      expect(
        ErrorHandler.getUserMessage(authEx),
        'Incorrect email or password. Please try again.',
      );
    });

    test('maps user already registered into friendly message', () {
      const authEx = supa.AuthException('User already registered');
      expect(
        ErrorHandler.getUserMessage(authEx),
        'An account with this email address already exists.',
      );
    });

    test('maps PostgrestException 42501 into permission denied message', () {
      const postgrestEx = supa.PostgrestException(
        message: 'permission denied for table profiles',
        code: '42501',
      );
      expect(
        ErrorHandler.getUserMessage(postgrestEx),
        'You do not have permission to view or modify this data.',
      );
    });

    test('maps network errors into connection message', () {
      final error = Exception('Failed host lookup: ClientException');
      expect(
        ErrorHandler.getUserMessage(error),
        'Unable to reach the server. Please check your internet connection.',
      );
    });

    test('returns fallback message for unknown exceptions', () {
      final error = Exception('Random internal error');
      expect(
        ErrorHandler.getUserMessage(error),
        'An unexpected error occurred. Please try again.',
      );
    });
  });
}

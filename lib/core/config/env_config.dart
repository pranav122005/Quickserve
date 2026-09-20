import '../errors/app_exception.dart';

/// Reads and validates compile-time environment configuration.
/// 
/// Variables should be passed at build/run time using:
/// `flutter run --dart-define-from-file=.env` or `--dart-define=...`
class EnvConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Validates that all required environment variables are set and properly formatted.
  static void validate() {
    if (supabaseUrl.isEmpty) {
      throw const ConfigurationException(
        'Missing SUPABASE_URL environment variable. '
        'Run the application with: flutter run -d chrome --dart-define-from-file=.env',
      );
    }

    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const ConfigurationException(
        'Invalid SUPABASE_URL format. Expected a valid HTTPS URL (e.g., https://<project>.supabase.co).',
      );
    }

    if (supabaseAnonKey.isEmpty) {
      throw const ConfigurationException(
        'Missing SUPABASE_ANON_KEY environment variable. '
        'Run the application with: flutter run -d chrome --dart-define-from-file=.env',
      );
    }
  }
}

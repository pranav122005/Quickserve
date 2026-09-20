import 'env_config.dart';

class SupabaseConfig {
  static String get url => EnvConfig.supabaseUrl;
  static String get publishableKey => EnvConfig.supabaseAnonKey;
  static String get anonKey => publishableKey;
}

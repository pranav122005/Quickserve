import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_controller.dart';
import 'auth_state.dart';
import '../../../../models/user_profile.dart';
import '../../../../models/user_role.dart';
import '../../../../services/supabase_service.dart';
import '../../../../repositories/auth_repository.dart';
import '../../../../repositories/auth_repository_impl.dart';
import '../../../../repositories/profile_repository.dart';
import '../../../../repositories/profile_repository_impl.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthRepositoryImpl(supabaseService);
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return ProfileRepositoryImpl(supabaseService);
});

final authControllerProvider =
    NotifierProvider<AuthController, AppAuthState>(AuthController.new);

final currentUserProfileProvider = Provider<UserProfile?>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.profile;
});

final currentUserRoleProvider = Provider<UserRole?>((ref) {
  final profile = ref.watch(currentUserProfileProvider);
  return profile?.role;
});

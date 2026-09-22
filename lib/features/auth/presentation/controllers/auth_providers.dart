import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_controller.dart';
import 'auth_state.dart';
import '../../../../models/user_profile.dart';
import '../../../../models/user_role.dart';

export '../../../../repositories/repository_providers.dart';

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

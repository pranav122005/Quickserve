import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import '../../../../models/user_profile.dart';
import '../../../../models/user_role.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  pendingConfirmation,
  error,
  profileError,
}

/// Represents the current authentication and user profile state.
class AppAuthState {
  final AuthStatus status;
  final supa.User? user;
  final UserProfile? profile;
  final String? errorMessage;

  const AppAuthState({
    required this.status,
    this.user,
    this.profile,
    this.errorMessage,
  });

  factory AppAuthState.initial() => const AppAuthState(status: AuthStatus.initial);

  factory AppAuthState.loading([supa.User? user]) =>
      AppAuthState(status: AuthStatus.loading, user: user);

  factory AppAuthState.authenticated({
    required supa.User user,
    required UserProfile profile,
  }) =>
      AppAuthState(
        status: AuthStatus.authenticated,
        user: user,
        profile: profile,
      );

  factory AppAuthState.unauthenticated() =>
      const AppAuthState(status: AuthStatus.unauthenticated);

  factory AppAuthState.pendingConfirmation(supa.User user) =>
      AppAuthState(status: AuthStatus.pendingConfirmation, user: user);

  factory AppAuthState.error(String message, {supa.User? user}) => AppAuthState(
        status: AuthStatus.error,
        user: user,
        errorMessage: message,
      );

  factory AppAuthState.profileError(String message, {supa.User? user}) =>
      AppAuthState(
        status: AuthStatus.profileError,
        user: user,
        errorMessage: message,
      );

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && profile != null;
  bool get isLoading => status == AuthStatus.loading;
  bool get isInitial => status == AuthStatus.initial;
  bool get isPendingConfirmation => status == AuthStatus.pendingConfirmation;
  bool get hasError => status == AuthStatus.error;
  bool get hasProfileError => status == AuthStatus.profileError;
  UserRole? get role => profile?.role;

  AppAuthState copyWith({
    AuthStatus? status,
    supa.User? user,
    UserProfile? profile,
    String? errorMessage,
  }) {
    return AppAuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      profile: profile ?? this.profile,
      errorMessage: errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppAuthState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          user?.id == other.user?.id &&
          profile == other.profile &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      status.hashCode ^
      (user?.id.hashCode ?? 0) ^
      (profile?.hashCode ?? 0) ^
      (errorMessage?.hashCode ?? 0);
}

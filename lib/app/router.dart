import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_constants.dart';
import '../models/user_role.dart';
import '../features/auth/presentation/controllers/auth_providers.dart';
import '../features/auth/presentation/controllers/auth_state.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/unauthorized_screen.dart';
import '../features/customer/presentation/screens/customer_dashboard.dart';
import '../features/agent/presentation/screens/agent_dashboard.dart';
import '../features/admin/presentation/screens/admin_dashboard.dart';

/// Pure routing guard logic separated for unit testing and router redirect evaluation.
String? computeRouteRedirect({
  required AppAuthState authState,
  required String currentPath,
}) {
  final isSplash = currentPath == AppRoutes.root;
  final isAuthRoute = currentPath == AppRoutes.login ||
      currentPath == AppRoutes.register;
  final isUnauthorized = currentPath == AppRoutes.unauthorized;

  // 1. Initial / startup state -> keep on splash screen
  if (authState.isInitial) {
    return isSplash ? null : AppRoutes.root;
  }

  // 2. Profile or role loading error -> show unauthorized / error screen
  if (authState.hasProfileError) {
    return isUnauthorized ? null : AppRoutes.unauthorized;
  }

  // 3. Unauthenticated state
  if (!authState.isAuthenticated) {
    // If still in middle of a login/register loading operation, keep current view
    if (authState.isLoading && isAuthRoute) {
      return null;
    }
    // Allow access to login and register screens
    if (isAuthRoute) {
      return null;
    }
    // All other screens require authentication -> redirect to login
    return AppRoutes.login;
  }

  // 4. Authenticated state
  final role = authState.role;
  if (role == null) {
    return isUnauthorized ? null : AppRoutes.unauthorized;
  }

  // Redirect from login, register, or splash to the user's role-specific dashboard
  if (isAuthRoute || isSplash) {
    switch (role) {
      case UserRole.customer:
        return AppRoutes.customer;
      case UserRole.agent:
        return AppRoutes.agent;
      case UserRole.admin:
        return AppRoutes.admin;
    }
  }

  // 5. Strict Role Protection Guards
  final isCustomerPath = currentPath.startsWith(AppRoutes.customer);
  final isAgentPath = currentPath.startsWith(AppRoutes.agent);
  final isAdminPath = currentPath.startsWith(AppRoutes.admin);

  if (role.isCustomer && (isAgentPath || isAdminPath)) {
    return AppRoutes.customer;
  }

  if (role.isAgent && (isCustomerPath || isAdminPath)) {
    return AppRoutes.agent;
  }

  if (role.isAdmin && (isCustomerPath || isAgentPath)) {
    return AppRoutes.admin;
  }

  // All checks passed
  return null;
}

/// Bridge between Riverpod AuthController changes and GoRouter refreshListenable.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authControllerProvider, (previous, next) {
      notifyListeners();
    });
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.root,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      return computeRouteRedirect(
        authState: authState,
        currentPath: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.root,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.customer,
        builder: (context, state) => const CustomerDashboard(),
      ),
      GoRoute(
        path: AppRoutes.agent,
        builder: (context, state) => const AgentDashboard(),
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => const AdminDashboard(),
      ),
      GoRoute(
        path: AppRoutes.unauthorized,
        builder: (context, state) => const UnauthorizedScreen(),
      ),
    ],
  );
});

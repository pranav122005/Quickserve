import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickserve/features/auth/presentation/controllers/auth_providers.dart';
import 'package:quickserve/features/auth/presentation/controllers/auth_controller.dart';
import 'package:quickserve/features/auth/presentation/controllers/auth_state.dart';
import 'package:quickserve/features/auth/presentation/screens/login_screen.dart';
import 'package:quickserve/features/auth/presentation/screens/register_screen.dart';

class MockAuthController extends AuthController {
  @override
  AppAuthState build() {
    return const AppAuthState(status: AuthStatus.unauthenticated);
  }
}

void main() {
  testWidgets('LoginScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(MockAuthController.new),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    expect(find.text('QuickServe'), findsOneWidget);
    expect(find.text('Sign in to your account'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('RegisterScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(MockAuthController.new),
        ],
        child: const MaterialApp(
          home: RegisterScreen(),
        ),
      ),
    );

    expect(find.text('QuickServe'), findsOneWidget);
    expect(find.text('Create your customer account'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Create Customer Account'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}

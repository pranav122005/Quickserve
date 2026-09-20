import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_role.dart';
import '../../features/auth/presentation/controllers/auth_providers.dart';

/// Reusable responsive dashboard layout for Customer, Agent, and Admin roles.
class DashboardShell extends ConsumerWidget {
  final String title;
  final UserRole role;
  final Widget body;
  final List<Widget>? actions;

  const DashboardShell({
    super.key,
    required this.title,
    required this.role,
    required this.body,
    this.actions,
  });

  Color _getRoleColor(UserRole role, BuildContext context) {
    switch (role) {
      case UserRole.customer:
        return Colors.teal;
      case UserRole.agent:
        return Colors.indigo;
      case UserRole.admin:
        return Colors.deepPurple;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider);
    final roleColor = _getRoleColor(role, context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.flash_on, color: Color(0xFF2563EB), size: 26),
            const SizedBox(width: 8),
            Text(
              'QuickServe',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: roleColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                role.displayName.toUpperCase(),
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (profile != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Text(
                  profile.fullName.isNotEmpty
                      ? profile.fullName
                      : 'Authenticated User',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
          ),
          const SizedBox(width: 8),
        ],
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade200, height: 1.0),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: body,
          ),
        ),
      ),
    );
  }
}

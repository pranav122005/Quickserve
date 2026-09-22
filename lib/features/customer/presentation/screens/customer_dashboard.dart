import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/dashboard_shell.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/priority_badge.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/service_request.dart';
import '../../../../models/user_role.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../controllers/customer_requests_controller.dart';
import 'create_request_dialog.dart';
import 'customer_tracking_screen.dart';
import 'request_details_dialog.dart';

class CustomerDashboard extends ConsumerStatefulWidget {
  const CustomerDashboard({super.key});

  @override
  ConsumerState<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends ConsumerState<CustomerDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openCreateRequestDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const CreateRequestDialog(),
    );
  }

  void _openDetailsDialog(ServiceRequest request) {
    showDialog(
      context: context,
      builder: (ctx) => RequestDetailsDialog(request: request),
    );
  }

  void _openTrackingScreen(ServiceRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => CustomerTrackingScreen(
          requestId: request.id,
          initialRequest: request,
        ),
      ),
    );
  }

  List<ServiceRequest> _filterRequests(List<ServiceRequest> all, int tabIndex) {
    switch (tabIndex) {
      case 1:
        return all.where((r) => r.status.isActive).toList();
      case 2:
        return all.where((r) => r.status.isCompleted).toList();
      case 3:
        return all.where((r) => r.status.isCancelled).toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider);
    final state = ref.watch(customerRequestsProvider);
    final theme = Theme.of(context);

    return DashboardShell(
      title: 'Customer Dashboard',
      role: UserRole.customer,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Welcome & Action Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF2563EB),
                  child: const Icon(Icons.person, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back, ${profile?.fullName.isNotEmpty == true ? profile!.fullName : "Customer"}!',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage and track your home & commercial service requests.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openCreateRequestDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // KPI Metrics Row
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                final cards = [
                  _metricCard(
                    title: 'Total Requests',
                    count: state.totalCount,
                    icon: Icons.assignment_outlined,
                    color: Colors.blue,
                  ),
                  _metricCard(
                    title: 'Active / In Progress',
                    count: state.activeCount,
                    icon: Icons.timelapse,
                    color: Colors.orange,
                  ),
                  _metricCard(
                    title: 'Completed',
                    count: state.completedCount,
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  _metricCard(
                    title: 'Cancelled',
                    count: state.cancelledCount,
                    icon: Icons.cancel_outlined,
                    color: Colors.red,
                  ),
                ];

                if (isWide) {
                  return Row(
                    children: cards
                        .map((c) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                child: c,
                              ),
                            ))
                        .toList(),
                  );
                } else {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: cards
                        .map((c) => SizedBox(
                              width: (constraints.maxWidth - 12) / 2,
                              child: c,
                            ))
                        .toList(),
                  );
                }
              },
            ),
            const SizedBox(height: 32),

            // Tabs & Request Table Section
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'My Service Requests',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh',
                          onPressed: () {
                            ref.read(customerRequestsProvider.notifier).loadRequests();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      onTap: (_) => setState(() {}),
                      tabs: [
                        Tab(text: 'All (${state.totalCount})'),
                        Tab(text: 'Active (${state.activeCount})'),
                        Tab(text: 'Completed (${state.completedCount})'),
                        Tab(text: 'Cancelled (${state.cancelledCount})'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (state.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(48.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (state.errorMessage != null)
                      ErrorView(
                        message: state.errorMessage!,
                        onRetry: () =>
                            ref.read(customerRequestsProvider.notifier).loadRequests(),
                      )
                    else ...[
                      Builder(
                        builder: (context) {
                          final filtered =
                              _filterRequests(state.requests, _tabController.index);

                          if (filtered.isEmpty) {
                            return EmptyStateView(
                              icon: Icons.assignment_outlined,
                              title: 'No Requests Found',
                              message: _tabController.index == 0
                                  ? 'You have not submitted any service requests yet. Click "New Request" to get started!'
                                  : 'No requests currently match this filter.',
                              actionLabel:
                                  _tabController.index == 0 ? 'Create First Request' : null,
                              onAction:
                                  _tabController.index == 0 ? _openCreateRequestDialog : null,
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final req = filtered[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.build_outlined,
                                    color: Color(0xFF2563EB),
                                    size: 20,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${req.formattedId} • ${req.title}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    StatusBadge.forRequest(req.status),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        PriorityBadge(priority: req.priority),
                                        const SizedBox(width: 8),
                                        Text(
                                          '•  ${req.category}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '•  ${Formatters.formatDate(req.createdAt)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      req.serviceAddress,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (req.status.isActive) ...[
                                      ElevatedButton.icon(
                                        onPressed: () => _openTrackingScreen(req),
                                        icon: const Icon(Icons.location_on, size: 14),
                                        label: const Text('Track Live', style: TextStyle(fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2563EB),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    OutlinedButton(
                                      onPressed: () => _openDetailsDialog(req),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      child: const Text('View', style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required int count,
    required IconData icon,
    required MaterialColor color,
  }) {
    return Card(
      elevation: 0,
      color: color.shade50.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.shade200.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color.shade700, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color.shade900,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: color.shade800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

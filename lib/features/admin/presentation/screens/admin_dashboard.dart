import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/dashboard_shell.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/priority_badge.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../models/service_request.dart';
import '../../../../models/user_role.dart';
import '../../../../services/audit_service.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../controllers/admin_controller.dart';
import 'admin_request_details_dialog.dart';
import 'manual_assign_dialog.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  RequestStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _inspectRequest(ServiceRequest request) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AdminRequestDetailsDialog(request: request),
    );
    if (result == true) {
      ref.read(adminDashboardProvider.notifier).loadAdminData();
    }
  }

  void _assignRequest(ServiceRequest request) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ManualAssignDialog(request: request),
    );
    if (result == true) {
      ref.read(adminDashboardProvider.notifier).loadAdminData();
    }
  }

  void _autoDispatch(ServiceRequest request) async {
    final result = await ref
        .read(adminDashboardProvider.notifier)
        .autoDispatch(request.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isSuccess
                ? (result.isOffered ? 'Offer dispatched to best available agent!' : result.message)
                : 'Dispatch result: ${result.message}',
          ),
          backgroundColor:
              result.isSuccess ? Colors.green : Colors.orange.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider);
    final adminState = ref.watch(adminDashboardProvider);
    final theme = Theme.of(context);

    return DashboardShell(
      title: 'Admin Operations',
      role: UserRole.admin,
      body: adminState.isLoading && adminState.requests.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(48.0),
                child: CircularProgressIndicator(),
              ),
            )
          : adminState.errorMessage != null && adminState.requests.isEmpty
              ? ErrorView(
                  message: adminState.errorMessage!,
                  onRetry: () =>
                      ref.read(adminDashboardProvider.notifier).loadAdminData(),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome & Operations Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome, ${profile?.fullName.isNotEmpty == true ? profile!.fullName : "Administrator"}',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Monitor requests, dispatch agents, and track operations.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh Data',
                          onPressed: () => ref
                              .read(adminDashboardProvider.notifier)
                              .loadAdminData(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // KPI Metrics Row
                    _buildKpiMetrics(adminState),
                    const SizedBox(height: 28),

                    // Tab Navigation
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: Colors.deepPurple.shade700,
                        unselectedLabelColor: Colors.grey.shade600,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.assignment_outlined, size: 18),
                                const SizedBox(width: 8),
                                Text('Requests (${adminState.requests.length})'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people_outline, size: 18),
                                const SizedBox(width: 8),
                                Text('Customers (${adminState.totalCustomers})'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.support_agent_outlined, size: 18),
                                const SizedBox(width: 8),
                                Text('Agents (${adminState.totalAgents})'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.payments_outlined, size: 18),
                                const SizedBox(width: 8),
                                Text('Payments (${adminState.totalPaymentsCount})'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shield_outlined, size: 18),
                                const SizedBox(width: 8),
                                Text('Audit Logs (${ref.watch(auditServiceProvider).events.length})'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tab Views
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 480),
                      child: SizedBox(
                        height: 520,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildRequestsTab(adminState),
                            _buildCustomersTab(adminState),
                            _buildAgentsTab(adminState),
                            _buildPaymentsTab(adminState),
                            _buildAuditLogsTab(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildKpiMetrics(AdminDashboardState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 800 ? 6 : 3;
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _kpiCard('Pending', state.pendingRequests.toString(),
                Icons.hourglass_top, Colors.amber.shade700, Colors.amber.shade50),
            _kpiCard('Active', state.activeRequests.toString(),
                Icons.run_circle_outlined, Colors.blue.shade700, Colors.blue.shade50),
            _kpiCard('Completed', state.completedRequests.toString(),
                Icons.check_circle_outline, Colors.green.shade700, Colors.green.shade50),
            _kpiCard('Customers', state.totalCustomers.toString(),
                Icons.people, Colors.purple.shade700, Colors.purple.shade50),
            _kpiCard('Agents', state.totalAgents.toString(),
                Icons.support_agent, Colors.indigo.shade700, Colors.indigo.shade50),
            _kpiCard('Revenue',
                Formatters.formatCurrency(state.totalRevenue, currency: 'INR'),
                Icons.currency_rupee, Colors.teal.shade700, Colors.teal.shade50),
          ],
        );
      },
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsTab(AdminDashboardState state) {
    var filtered = state.requests;
    if (_statusFilter != null) {
      filtered = filtered.where((r) => r.status == _statusFilter).toList();
    }

    return Column(
      children: [
        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('All Requests'),
                selected: _statusFilter == null,
                onSelected: (selected) {
                  if (selected) setState(() => _statusFilter = null);
                },
              ),
              const SizedBox(width: 8),
              ...RequestStatus.values.map(
                (status) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(status.displayName),
                    selected: _statusFilter == status,
                    onSelected: (selected) {
                      setState(() {
                        _statusFilter = selected ? status : null;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Requests List
        Expanded(
          child: filtered.isEmpty
              ? EmptyStateView(
                  icon: Icons.inbox_outlined,
                  title: 'No requests found',
                  message: _statusFilter != null
                      ? 'No requests with status "${_statusFilter!.displayName}".'
                      : 'No customer service requests registered yet.',
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final req = filtered[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${req.formattedId} • ${req.title}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          PriorityBadge(priority: req.priority),
                          const SizedBox(width: 8),
                          StatusBadge.forRequest(req.status),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Row(
                          children: [
                            Icon(Icons.category_outlined,
                                size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(req.category,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade700)),
                            const SizedBox(width: 16),
                            Icon(Icons.calendar_today_outlined,
                                size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              Formatters.formatDateTime(req.createdAt),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade700),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.place_outlined,
                                size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                req.serviceAddress,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (req.status.isPending || req.status.isDispatching) ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                              ),
                              icon: const Icon(Icons.radar, size: 14),
                              label: Text(
                                req.status.isDispatching ? 'Retry Dispatch' : 'Dispatch',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () => _autoDispatch(req),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (req.status.isPending) ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              icon: const Icon(Icons.person_add, size: 16),
                              label: const Text('Assign',
                                  style: TextStyle(fontSize: 12)),
                              onPressed: () => _assignRequest(req),
                            ),
                            const SizedBox(width: 8),
                          ],
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            child: const Text('Inspect',
                                style: TextStyle(fontSize: 12)),
                            onPressed: () => _inspectRequest(req),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCustomersTab(AdminDashboardState state) {
    if (state.customers.isEmpty) {
      return const EmptyStateView(
        icon: Icons.people_outline,
        title: 'No Customers Found',
        message: 'No registered customer accounts yet.',
      );
    }

    return ListView.separated(
      itemCount: state.customers.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final c = state.customers[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.purple.shade100,
            foregroundColor: Colors.purple.shade900,
            child: Text(
              c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : 'C',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            c.fullName.isNotEmpty ? c.fullName : 'Customer (${c.id})',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'Phone: ${c.phone ?? "N/A"} • ID: ${c.id}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          trailing: Text(
            Formatters.formatDateTime(c.createdAt),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        );
      },
    );
  }

  Widget _buildAgentsTab(AdminDashboardState state) {
    if (state.agents.isEmpty) {
      return const EmptyStateView(
        icon: Icons.support_agent_outlined,
        title: 'No Agents Found',
        message: 'No service agent accounts configured yet.',
      );
    }

    return ListView.separated(
      itemCount: state.agents.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final a = state.agents[index];
        final name = a.userProfile?.fullName.isNotEmpty == true
            ? a.userProfile!.fullName
            : 'Agent ${a.userId.substring(0, 8)}';

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.indigo.shade100,
            foregroundColor: Colors.indigo.shade900,
            child: Text(
              name[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          title: Row(
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              if (a.isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Text(
                    'Verified',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade800),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            'Radius: ${a.serviceRadiusKm.toStringAsFixed(1)} km • User ID: ${a.userId}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: a.availability.isAvailable
                  ? Colors.green.shade50
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: a.availability.isAvailable
                    ? Colors.green.shade300
                    : Colors.grey.shade300,
              ),
            ),
            child: Text(
              a.availability.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: a.availability.isAvailable
                    ? Colors.green.shade800
                    : Colors.grey.shade700,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentsTab(AdminDashboardState state) {
    if (state.payments.isEmpty) {
      return const EmptyStateView(
        icon: Icons.payments_outlined,
        title: 'No Payments Recorded',
        message: 'No completed job payments have been logged yet.',
      );
    }

    return ListView.separated(
      itemCount: state.payments.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final p = state.payments[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.teal.shade50,
            foregroundColor: Colors.teal.shade700,
            child: const Icon(Icons.currency_rupee, size: 20),
          ),
          title: Row(
            children: [
              Text(
                Formatters.formatCurrency(p.amount, currency: p.currency),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  p.method.displayName,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ),
              const Spacer(),
              StatusBadge.forPayment(p.status),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Request ID: ${p.requestId} • Customer: ${p.customerId.substring(0, 8)}... • Agent: ${p.agentId.substring(0, 8)}...',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          trailing: p.paidAt != null
              ? Text(
                  Formatters.formatDateTime(p.paidAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                )
              : null,
        );
      },
    );
  }

  Widget _buildAuditLogsTab() {
    final auditService = ref.watch(auditServiceProvider);
    final events = auditService.events;

    if (events.isEmpty) {
      return const EmptyStateView(
        icon: Icons.shield_outlined,
        title: 'No Audit Events Logged',
        message: 'Platform audit events (logins, requests, assignments, auth events) will appear here in real-time.',
      );
    }

    return ListView.separated(
      itemCount: events.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final ev = events[index];
        Color badgeColor;
        switch (ev.eventType) {
          case AuditEventType.loginSuccess:
            badgeColor = Colors.green;
            break;
          case AuditEventType.requestCreated:
            badgeColor = Colors.blue;
            break;
          case AuditEventType.requestAssigned:
            badgeColor = Colors.teal;
            break;
          case AuditEventType.requestUpdated:
            badgeColor = Colors.purple;
            break;
          case AuditEventType.authorizationFailed:
            badgeColor = Colors.red;
            break;
          case AuditEventType.databaseError:
            badgeColor = Colors.deepOrange;
            break;
          default:
            badgeColor = Colors.grey;
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: badgeColor.withValues(alpha: 0.15),
            child: Icon(Icons.security, color: badgeColor, size: 20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  ev.eventType,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                Formatters.formatDateTime(ev.timestamp),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ev.details,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  'Actor: ${ev.actorId}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

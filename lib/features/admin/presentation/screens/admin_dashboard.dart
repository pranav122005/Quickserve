import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/dashboard_shell.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/priority_badge.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/quickserve_components.dart';
import '../../../../models/service_request.dart';
import '../../../../models/user_role.dart';
import '../../../../services/audit_service.dart';
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
              result.isSuccess ? const Color(0xFF10B981) : const Color(0xFFD97706),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminDashboardProvider);

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
                    // Header Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Overview & Operations',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Real-time platform metrics, request management, and manual dispatch control.',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => ref.read(adminDashboardProvider.notifier).loadAdminData(),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Refresh Data'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Real-Time Backend Stat KPI Cards
                    _buildKpiMetrics(adminState),
                    const SizedBox(height: 28),

                    // Tab Navigation Bar
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: const Color(0xFF2563EB),
                        unselectedLabelColor: const Color(0xFF64748B),
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        tabs: [
                          Tab(text: 'Requests (${adminState.requests.length})'),
                          Tab(text: 'Customers (${adminState.totalCustomers})'),
                          Tab(text: 'Agents (${adminState.totalAgents})'),
                          Tab(text: 'Payments (${adminState.totalPaymentsCount})'),
                          Tab(text: 'Audit Logs (${ref.watch(auditServiceProvider).events.length})'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tab Views
                    SizedBox(
                      height: 540,
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
                  ],
                ),
    );
  }

  Widget _buildKpiMetrics(AdminDashboardState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        final count = isWide ? 4 : 2;

        return GridView.count(
          crossAxisCount: count,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isWide ? 2.4 : 1.8,
          children: [
            QuickServeStatCard(
              title: 'Total Requests',
              value: state.requests.length.toString(),
              icon: Icons.assignment_rounded,
              iconColor: const Color(0xFF2563EB),
              iconBgColor: const Color(0xFFEFF6FF),
            ),
            QuickServeStatCard(
              title: 'Active Requests',
              value: state.activeRequests.toString(),
              icon: Icons.timelapse_rounded,
              iconColor: const Color(0xFFD97706),
              iconBgColor: const Color(0xFFFFFBEB),
            ),
            QuickServeStatCard(
              title: 'Available Agents',
              value: state.agents.where((a) => a.availability.isAvailable).length.toString(),
              icon: Icons.engineering_rounded,
              iconColor: const Color(0xFF10B981),
              iconBgColor: const Color(0xFFECFDF5),
            ),
            QuickServeStatCard(
              title: 'Completed Jobs',
              value: state.completedRequests.toString(),
              icon: Icons.check_circle_rounded,
              iconColor: const Color(0xFF4F46E5),
              iconBgColor: const Color(0xFFEEF2FF),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRequestsTab(AdminDashboardState state) {
    var filtered = state.requests;
    if (_statusFilter != null) {
      filtered = filtered.where((r) => r.status == _statusFilter).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
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
                  child: ChoiceChip(
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

        // Requests List Card Table
        Expanded(
          child: filtered.isEmpty
              ? const QuickServeCard(
                  child: EmptyStateView(
                    icon: Icons.inbox_rounded,
                    title: 'No requests found',
                    message: 'No service requests currently match the selected filter.',
                  ),
                )
              : QuickServeCard(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final req = filtered[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: ServiceCategoryHelper.getBgColor(req.category),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                ServiceCategoryHelper.getIcon(req.category),
                                color: ServiceCategoryHelper.getColor(req.category),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${req.formattedId} • ${req.title}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Customer: ${req.customerProfile?.fullName ?? req.customerId.substring(0, 8)} • Address: ${req.serviceAddress}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            PriorityBadge(priority: req.priority),
                            const SizedBox(width: 8),
                            StatusBadge.forRequest(req.status),
                            const SizedBox(width: 16),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (req.status.isPending || req.status.isDispatching)
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.radar_rounded, size: 14),
                                    label: Text(
                                      req.status.isDispatching ? 'Retry' : 'Dispatch',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () => _autoDispatch(req),
                                  ),
                                if (req.status.isPending) ...[
                                  const SizedBox(width: 6),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4F46E5),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.person_add_rounded, size: 14),
                                    label: const Text('Assign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    onPressed: () => _assignRequest(req),
                                  ),
                                ],
                                const SizedBox(width: 6),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  child: const Text('Inspect', style: TextStyle(fontSize: 12, color: Color(0xFF0F172A))),
                                  onPressed: () => _inspectRequest(req),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCustomersTab(AdminDashboardState state) {
    if (state.customers.isEmpty) {
      return const QuickServeCard(
        child: EmptyStateView(
          icon: Icons.people_outline_rounded,
          title: 'No Customers Found',
          message: 'No registered customer accounts yet.',
        ),
      );
    }

    return QuickServeCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: state.customers.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final c = state.customers[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFEFF6FF),
              foregroundColor: const Color(0xFF2563EB),
              child: Text(
                c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : 'C',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              c.fullName.isNotEmpty ? c.fullName : 'Customer (${c.id})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
            ),
            subtitle: Text(
              'Phone: ${c.phone ?? "N/A"} • ID: ${c.id}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            trailing: Text(
              Formatters.formatDateTime(c.createdAt),
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAgentsTab(AdminDashboardState state) {
    if (state.agents.isEmpty) {
      return const QuickServeCard(
        child: EmptyStateView(
          icon: Icons.engineering_rounded,
          title: 'No Agents Found',
          message: 'No service agent accounts configured yet.',
        ),
      );
    }

    return QuickServeCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: state.agents.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final a = state.agents[index];
          final name = a.userProfile?.fullName.isNotEmpty == true
              ? a.userProfile!.fullName
              : 'Agent ${a.userId.substring(0, 8)}';

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFECFDF5),
              foregroundColor: const Color(0xFF10B981),
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Row(
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                const SizedBox(width: 8),
                if (a.isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Text(
                      'Verified Agent',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              'Radius: ${a.serviceRadiusKm.toStringAsFixed(1)} km • User ID: ${a.userId}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            trailing: StatusBadge(
              label: a.availability.displayName,
              color: a.availability.isAvailable ? const Color(0xFF10B981) : const Color(0xFF64748B),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentsTab(AdminDashboardState state) {
    if (state.payments.isEmpty) {
      return const QuickServeCard(
        child: EmptyStateView(
          icon: Icons.payments_outlined,
          title: 'No Payments Recorded',
          message: 'No completed job payments have been logged yet.',
        ),
      );
    }

    return QuickServeCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: state.payments.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final p = state.payments[index];
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFECFDF5),
              foregroundColor: Color(0xFF10B981),
              child: Icon(Icons.currency_rupee_rounded, size: 20),
            ),
            title: Row(
              children: [
                Text(
                  Formatters.formatCurrency(p.amount, currency: p.currency),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    p.method.displayName,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
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
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
            trailing: p.paidAt != null
                ? Text(
                    Formatters.formatDateTime(p.paidAt),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildAuditLogsTab() {
    final auditService = ref.watch(auditServiceProvider);
    final events = auditService.events;

    if (events.isEmpty) {
      return const QuickServeCard(
        child: EmptyStateView(
          icon: Icons.shield_outlined,
          title: 'No Audit Events Logged',
          message: 'Platform audit events (logins, requests, assignments, auth events) will appear here in real-time.',
        ),
      );
    }

    return QuickServeCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: events.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final ev = events[index];
          Color badgeColor;
          switch (ev.eventType) {
            case AuditEventType.loginSuccess:
              badgeColor = const Color(0xFF10B981);
              break;
            case AuditEventType.requestCreated:
              badgeColor = const Color(0xFF2563EB);
              break;
            case AuditEventType.requestAssigned:
              badgeColor = const Color(0xFF4F46E5);
              break;
            case AuditEventType.authorizationFailed:
              badgeColor = const Color(0xFFEF4444);
              break;
            default:
              badgeColor = const Color(0xFF64748B);
          }

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            leading: CircleAvatar(
              backgroundColor: badgeColor.withValues(alpha: 0.1),
              child: Icon(Icons.security_rounded, color: badgeColor, size: 20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
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
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Actor ID: ${ev.actorId}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

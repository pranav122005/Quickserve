import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/priority_badge.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../models/service_request.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../controllers/customer_requests_controller.dart';
import '../widgets/customer_request_details_sheet.dart';
import 'customer_mobile_create_request_screen.dart';
import 'customer_tracking_screen.dart';

/// Material 3 mobile navigation shell for Customers.
class CustomerMobileShell extends ConsumerStatefulWidget {
  const CustomerMobileShell({super.key});

  @override
  ConsumerState<CustomerMobileShell> createState() => _CustomerMobileShellState();
}

class _CustomerMobileShellState extends ConsumerState<CustomerMobileShell> {
  int _currentIndex = 0;
  RequestStatus? _requestsFilter;

  @override
  void initState() {
    super.initState();
    // Authoritative state load on mobile startup to ensure active requests survive restarts
    Future.microtask(() {
      ref.read(customerRequestsProvider.notifier).loadRequests();
    });
  }

  void _openCreateRequest() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CustomerMobileCreateRequestScreen(),
      ),
    );
  }

  void _openTracking(ServiceRequest req) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerTrackingScreen(
          requestId: req.id,
          initialRequest: req,
        ),
      ),
    );
  }

  void _showRequestDetails(ServiceRequest req) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerRequestDetailsSheet(
        request: req,
        onRequestCancelled: () {
          ref.read(customerRequestsProvider.notifier).loadRequests();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          _buildRequestsTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    final profile = ref.watch(currentUserProfileProvider);
    final state = ref.watch(customerRequestsProvider);
    final activeRequests = state.requests.where((r) => r.status.isActive).toList();
    final recentRequests = state.requests.take(3).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(customerRequestsProvider.notifier).loadRequests(),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF2563EB),
                    child: const Icon(Icons.person, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${profile?.fullName.isNotEmpty == true ? profile!.fullName.split(' ').first : 'Customer'} 👋',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Need quick assistance with your home?',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Active Request Spotlight Card (if any active)
              if (activeRequests.isNotEmpty) ...[
                _buildActiveRequestHeroCard(activeRequests.first),
                const SizedBox(height: 20),
              ],

              // Quick Action Hero Card
              Card(
                elevation: 0,
                color: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Book a Service',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Connect with verified plumbers, electricians, and technicians nearby.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _openCreateRequest,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New Request'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Summary KPI Counters
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Total',
                      count: state.totalCount,
                      icon: Icons.list_alt,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Active',
                      count: state.activeCount,
                      icon: Icons.timelapse,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Done',
                      count: state.completedCount,
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Recent Requests Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Requests',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (state.requests.length > 3)
                    TextButton(
                      onPressed: () => setState(() => _currentIndex = 1),
                      child: const Text('View All'),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              if (state.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (recentRequests.isEmpty)
                EmptyStateView(
                  icon: Icons.inbox_outlined,
                  title: 'No requests yet',
                  message: 'Tap "New Request" above to get started.',
                )
              else
                ...recentRequests.map((req) => _buildRequestCard(req)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveRequestHeroCard(ServiceRequest req) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade300, width: 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.radar, color: Color(0xFF2563EB), size: 18),
                ),
                const SizedBox(width: 8),
                const Text(
                  'ACTIVE SERVICE REQUEST',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const Spacer(),
                StatusBadge.forRequest(req.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${req.formattedId} • ${req.title}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    req.serviceAddress,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                PriorityBadge(priority: req.priority),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _openTracking(req),
                  icon: const Icon(Icons.location_on, size: 16),
                  label: const Text('Track Live'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required int count,
    required IconData icon,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.shade700, size: 18),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color.shade900,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.shade700, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsTab() {
    final state = ref.watch(customerRequestsProvider);
    var list = state.requests;
    if (_requestsFilter != null) {
      list = list.where((r) => r.status == _requestsFilter).toList();
    }

    return SafeArea(
      child: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _requestsFilter == null,
                    onSelected: (s) {
                      if (s) setState(() => _requestsFilter = null);
                    },
                  ),
                  const SizedBox(width: 8),
                  ...RequestStatus.values.map(
                    (st) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(st.displayName),
                        selected: _requestsFilter == st,
                        onSelected: (selected) {
                          setState(() => _requestsFilter = selected ? st : null);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Requests List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(customerRequestsProvider.notifier).loadRequests(),
              child: list.isEmpty
                  ? Center(
                      child: EmptyStateView(
                        icon: Icons.assignment_outlined,
                        title: 'No requests',
                        message: _requestsFilter != null
                            ? 'No requests with status "${_requestsFilter!.displayName}".'
                            : 'You have not submitted any service requests yet.',
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        return _buildRequestCard(list[index]);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(ServiceRequest req) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showRequestDetails(req),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${req.formattedId} • ${req.title}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PriorityBadge(priority: req.priority),
                  const SizedBox(width: 6),
                  StatusBadge.forRequest(req.status),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.category_outlined, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    req.category,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    Formatters.formatDate(req.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      req.serviceAddress,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (req.status.isActive) ...[
                    ElevatedButton.icon(
                      onPressed: () => _openTracking(req),
                      icon: const Icon(Icons.location_on, size: 14),
                      label: const Text('Track Live', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  OutlinedButton(
                    onPressed: () => _showRequestDetails(req),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text('Details', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    final profile = ref.watch(currentUserProfileProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: const Color(0xFF2563EB),
                    child: Text(
                      profile?.fullName.isNotEmpty == true
                          ? profile!.fullName[0].toUpperCase()
                          : 'C',
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                profile?.fullName.isNotEmpty == true ? profile!.fullName : 'Customer Account',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  'Verified Customer',
                  style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Profile Information Cards
            Card(
              elevation: 0,
              color: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.phone_outlined, color: Colors.blue),
                    title: const Text('Phone Number', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    subtitle: Text(
                      profile?.phone != null && profile!.phone!.isNotEmpty
                          ? profile.phone!
                          : 'Not provided',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined, color: Colors.blue),
                    title: const Text('Account Role', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    subtitle: Text(
                      profile?.role.name.toUpperCase() ?? 'CUSTOMER',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Logout Button
            OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to log out of QuickServe?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Log Out', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(authControllerProvider.notifier).signOut();
                }
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Log Out', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

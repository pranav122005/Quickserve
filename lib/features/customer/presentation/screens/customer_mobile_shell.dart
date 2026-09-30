import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/priority_badge.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/quickserve_components.dart';
import '../../../../core/widgets/quickserve_skeleton.dart';
import '../../../../models/service_request.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../controllers/customer_requests_controller.dart';
import '../widgets/customer_request_details_sheet.dart';
import 'customer_mobile_create_request_screen.dart';
import 'customer_tracking_screen.dart';

/// Material 3 classic light theme mobile navigation shell for Customers.
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
    Future.microtask(() {
      ref.read(customerRequestsProvider.notifier).loadRequests();
    });
  }

  void _openCreateRequest([String? initialCategory]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerMobileCreateRequestScreen(initialCategory: initialCategory),
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          _buildRequestsTab(filterHistoryOnly: false),
          _buildRequestsTab(filterHistoryOnly: true),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: const Color(0xFF2563EB),
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment_rounded),
              label: 'Requests',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              activeIcon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    final profile = ref.watch(currentUserProfileProvider);
    final state = ref.watch(customerRequestsProvider);
    final activeRequests = state.requests.where((r) => r.status.isActive).toList();
    final firstName = profile?.fullName.isNotEmpty == true ? profile!.fullName.split(' ').first : 'Customer';

    return RefreshIndicator(
      onRefresh: () => ref.read(customerRequestsProvider.notifier).loadRequests(),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Premium Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFDBEAFE), width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        firstName.isNotEmpty ? firstName[0].toUpperCase() : 'C',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_getGreeting()}, $firstName',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Need a service? Book a trusted professional in just a few steps.',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Primary CTA Button Bar
              ElevatedButton.icon(
                onPressed: () => _openCreateRequest(),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  '+ Request a Service',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 24),

              // Category Cards Section
              const Text(
                'Service Categories',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildCategoryCard('AC Service', Icons.ac_unit_rounded, const Color(0xFF0284C7), const Color(0xFFE0F2FE))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildCategoryCard('Plumbing', Icons.plumbing_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildCategoryCard('Electrical', Icons.electrical_services_rounded, const Color(0xFFD97706), const Color(0xFFFFFBEB))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildCategoryCard('Cleaning', Icons.cleaning_services_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5))),
                ],
              ),
              const SizedBox(height: 28),

              // ACTIVE REQUESTS Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'ACTIVE REQUESTS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (activeRequests.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            activeRequests.length.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (activeRequests.length > 2)
                    TextButton(
                      onPressed: () => setState(() => _currentIndex = 1),
                      child: const Text('See All'),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (state.isLoading)
                const QuickServeSkeletonList(itemCount: 2, itemHeight: 140)
              else if (activeRequests.isEmpty)
                QuickServeCard(
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF64748B), size: 28),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No Active Requests',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'You don\'t have any active service bookings right now.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...activeRequests.map((req) => _buildActiveRequestItemCard(req)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String name, IconData icon, Color color, Color bg) {
    return InkWell(
      onTap: () => _openCreateRequest(name),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRequestItemCard(ServiceRequest req) {
    final catIcon = ServiceCategoryHelper.getIcon(req.category);
    final catColor = ServiceCategoryHelper.getColor(req.category);
    final catBg = ServiceCategoryHelper.getBgColor(req.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: catBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(catIcon, color: catColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${req.formattedId} • ${Formatters.formatDate(req.createdAt)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              StatusBadge.forRequest(req.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  req.serviceAddress,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
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
                icon: const Icon(Icons.navigation_rounded, size: 14),
                label: const Text('Track Live', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _showRequestDetails(req),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: const Text('View Details', style: TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsTab({required bool filterHistoryOnly}) {
    final state = ref.watch(customerRequestsProvider);
    var list = state.requests;

    if (filterHistoryOnly) {
      list = list.where((r) => r.status.isCompleted || r.status.isCancelled).toList();
    } else if (_requestsFilter != null) {
      list = list.where((r) => r.status == _requestsFilter).toList();
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  filterHistoryOnly ? 'Request History' : 'All Service Requests',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
                  onPressed: () => ref.read(customerRequestsProvider.notifier).loadRequests(),
                ),
              ],
            ),
          ),
          if (!filterHistoryOnly)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
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
                        child: ChoiceChip(
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
          const SizedBox(height: 10),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(customerRequestsProvider.notifier).loadRequests(),
              child: state.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: QuickServeSkeletonList(itemCount: 4),
                    )
                  : list.isEmpty
                      ? Center(
                          child: EmptyStateView(
                            icon: filterHistoryOnly ? Icons.history_rounded : Icons.assignment_outlined,
                            title: filterHistoryOnly ? 'No History Found' : 'No Requests Found',
                            message: filterHistoryOnly
                                ? 'Completed or cancelled service requests will appear here.'
                                : 'You don\'t have any service requests in this view.',
                            actionLabel: filterHistoryOnly ? null : 'Book Service Now',
                            onAction: filterHistoryOnly ? null : () => _openCreateRequest(),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            return _buildActiveRequestItemCard(list[index]);
                          },
                        ),
            ),
          ),
        ],
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
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFDBEAFE), width: 2),
                ),
                child: Center(
                  child: Text(
                    profile?.fullName.isNotEmpty == true ? profile!.fullName[0].toUpperCase() : 'C',
                    style: const TextStyle(color: Color(0xFF2563EB), fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                profile?.fullName.isNotEmpty == true ? profile!.fullName : 'Customer Account',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Text(
                  'Verified Customer',
                  style: TextStyle(color: Color(0xFF059669), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 28),

            QuickServeCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.phone_outlined, color: Color(0xFF2563EB)),
                    title: const Text('Phone Number', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    subtitle: Text(
                      profile?.phone != null && profile!.phone!.isNotEmpty ? profile.phone! : 'Not provided',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined, color: Color(0xFF2563EB)),
                    title: const Text('Account Role', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    subtitle: Text(
                      profile?.role.name.toUpperCase() ?? 'CUSTOMER',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

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
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
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
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
              label: const Text('Log Out', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

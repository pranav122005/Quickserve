import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/service_request.dart';
import '../../../../models/user_profile.dart';
import '../../../../models/agent_profile.dart';
import '../../../../models/payment_record.dart';
import '../../../../models/dispatch_result.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../core/errors/error_handler.dart';

class AdminDashboardState {
  final bool isLoading;
  final List<ServiceRequest> requests;
  final List<UserProfile> customers;
  final List<AgentProfile> agents;
  final List<PaymentRecord> payments;
  final String? errorMessage;

  const AdminDashboardState({
    this.isLoading = false,
    this.requests = const [],
    this.customers = const [],
    this.agents = const [],
    this.payments = const [],
    this.errorMessage,
  });

  int get totalCustomers => customers.length;
  int get totalAgents => agents.length;
  int get pendingRequests => requests.where((r) => r.status.isPending).length;
  int get activeRequests => requests.where((r) => r.status.isActive).length;
  int get completedRequests => requests.where((r) => r.status.isCompleted).length;
  int get totalPaymentsCount => payments.length;
  double get totalRevenue =>
      payments.where((p) => p.status.isPaid).fold(0.0, (sum, p) => sum + p.amount);

  AdminDashboardState copyWith({
    bool? isLoading,
    List<ServiceRequest>? requests,
    List<UserProfile>? customers,
    List<AgentProfile>? agents,
    List<PaymentRecord>? payments,
    String? errorMessage,
  }) {
    return AdminDashboardState(
      isLoading: isLoading ?? this.isLoading,
      requests: requests ?? this.requests,
      customers: customers ?? this.customers,
      agents: agents ?? this.agents,
      payments: payments ?? this.payments,
      errorMessage: errorMessage,
    );
  }
}

class AdminDashboardController extends Notifier<AdminDashboardState> {
  @override
  AdminDashboardState build() {
    Future.microtask(() => loadAdminData());
    return const AdminDashboardState(isLoading: true);
  }

  Future<void> loadAdminData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final reqRepo = ref.read(serviceRequestRepositoryProvider);
      final profileRepo = ref.read(profileRepositoryProvider);
      final agentProfileRepo = ref.read(agentProfileRepositoryProvider);
      final paymentRepo = ref.read(paymentRepositoryProvider);

      final results = await Future.wait([
        reqRepo.getAllRequests(),
        profileRepo.getAllCustomers(),
        agentProfileRepo.getAllAgents(),
        paymentRepo.getAllPayments(),
      ]);

      state = AdminDashboardState(
        isLoading: false,
        requests: results[0] as List<ServiceRequest>,
        customers: results[1] as List<UserProfile>,
        agents: results[2] as List<AgentProfile>,
        payments: results[3] as List<PaymentRecord>,
      );
    } catch (e) {
      final message = ErrorHandler.getUserMessage(e);
      state = state.copyWith(isLoading: false, errorMessage: message);
    }
  }

  Future<bool> assignRequest({
    required String requestId,
    required String agentId,
  }) async {
    try {
      final assignRepo = ref.read(assignmentRepositoryProvider);
      await assignRepo.manualAssign(requestId: requestId, agentId: agentId);
      await loadAdminData();
      return true;
    } catch (e) {
      final message = ErrorHandler.getUserMessage(e);
      state = state.copyWith(errorMessage: message);
      return false;
    }
  }

  Future<DispatchResult> autoDispatch(String requestId) async {
    try {
      final dispatchService = ref.read(dispatchServiceProvider);
      final result = await dispatchService.dispatchRequest(requestId);
      await loadAdminData();
      return result;
    } catch (e) {
      final message = ErrorHandler.getUserMessage(e);
      state = state.copyWith(errorMessage: message);
      return DispatchResult.error(message);
    }
  }
}

final adminDashboardProvider =
    NotifierProvider<AdminDashboardController, AdminDashboardState>(
  AdminDashboardController.new,
);

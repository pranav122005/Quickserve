import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/service_request.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../../../core/errors/error_handler.dart';

class CustomerRequestsState {
  final bool isLoading;
  final List<ServiceRequest> requests;
  final String? errorMessage;

  const CustomerRequestsState({
    this.isLoading = false,
    this.requests = const [],
    this.errorMessage,
  });

  int get totalCount => requests.length;
  int get activeCount => requests.where((r) => r.status.isActive).length;
  int get completedCount => requests.where((r) => r.status.isCompleted).length;
  int get cancelledCount => requests.where((r) => r.status.isCancelled).length;

  CustomerRequestsState copyWith({
    bool? isLoading,
    List<ServiceRequest>? requests,
    String? errorMessage,
  }) {
    return CustomerRequestsState(
      isLoading: isLoading ?? this.isLoading,
      requests: requests ?? this.requests,
      errorMessage: errorMessage,
    );
  }
}

class CustomerRequestsController extends Notifier<CustomerRequestsState> {
  @override
  CustomerRequestsState build() {
    Future.microtask(() => loadRequests());
    return const CustomerRequestsState(isLoading: true);
  }

  Future<void> loadRequests() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) {
      state = const CustomerRequestsState(errorMessage: 'User is not authenticated.');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = ref.read(serviceRequestRepositoryProvider);
      final list = await repo.getCustomerRequests(user.id);
      state = CustomerRequestsState(requests: list, isLoading: false);
    } catch (e) {
      final message = ErrorHandler.getUserMessage(e);
      state = state.copyWith(isLoading: false, errorMessage: message);
    }
  }

  Future<ServiceRequest?> createRequest({
    required String category,
    required String title,
    String? description,
    required String serviceAddress,
    required RequestPriority priority,
    double? latitude,
    double? longitude,
  }) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return null;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = ref.read(serviceRequestRepositoryProvider);
      final created = await repo.createRequest(
        customerId: user.id,
        category: category,
        title: title,
        description: description,
        serviceAddress: serviceAddress,
        priority: priority,
        latitude: latitude,
        longitude: longitude,
      );

      try {
        await ref.read(dispatchServiceProvider).dispatchRequest(created.id);
      } catch (e) {
        // Non-fatal: automatic database trigger will also attempt dispatch
      }

      await loadRequests();
      return created;
    } catch (e) {
      final message = ErrorHandler.getUserMessage(e);
      state = state.copyWith(isLoading: false, errorMessage: message);
      return null;
    }
  }

  Future<bool> cancelRequest(String requestId) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = ref.read(serviceRequestRepositoryProvider);
      await repo.cancelRequest(requestId, changedBy: user?.id);
      await loadRequests();
      return true;
    } catch (e) {
      final message = ErrorHandler.getUserMessage(e);
      state = state.copyWith(isLoading: false, errorMessage: message);
      return false;
    }
  }
}

final customerRequestsProvider =
    NotifierProvider<CustomerRequestsController, CustomerRequestsState>(
  CustomerRequestsController.new,
);

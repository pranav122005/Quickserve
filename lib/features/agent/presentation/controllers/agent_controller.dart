import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../models/agent_profile.dart';
import '../../../../models/service_assignment.dart';
import '../../../../models/payment_record.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../../../core/errors/error_handler.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../services/audit_service.dart';
import 'agent_location_controller.dart';

class AgentDashboardState {
  final bool isLoading;
  final AgentProfile? agentProfile;
  final ServiceAssignment? activeAssignment;
  final List<ServiceAssignment> incomingOffers;
  final List<ServiceAssignment> history;
  final String? errorMessage;

  const AgentDashboardState({
    this.isLoading = false,
    this.agentProfile,
    this.activeAssignment,
    this.incomingOffers = const [],
    this.history = const [],
    this.errorMessage,
  });

  bool get isAvailable => agentProfile?.availability.isAvailable ?? false;
  double get serviceRadiusKm => agentProfile?.serviceRadiusKm ?? 15.0;

  AgentDashboardState copyWith({
    bool? isLoading,
    AgentProfile? agentProfile,
    ServiceAssignment? activeAssignment,
    List<ServiceAssignment>? incomingOffers,
    List<ServiceAssignment>? history,
    String? errorMessage,
  }) {
    return AgentDashboardState(
      isLoading: isLoading ?? this.isLoading,
      agentProfile: agentProfile ?? this.agentProfile,
      activeAssignment: activeAssignment ?? this.activeAssignment,
      incomingOffers: incomingOffers ?? this.incomingOffers,
      history: history ?? this.history,
      errorMessage: errorMessage,
    );
  }
}

class AgentDashboardController extends Notifier<AgentDashboardState> {
  RealtimeChannel? _offersChannel;
  RealtimeChannel? _requestsChannel;

  @override
  AgentDashboardState build() {
    ref.onDispose(() {
      _offersChannel?.unsubscribe();
      _requestsChannel?.unsubscribe();
      ref.read(agentLocationControllerProvider.notifier).stopPublishing();
    });

    Future.microtask(() => loadAgentData());
    return const AgentDashboardState(isLoading: true);
  }

  Future<void> loadAgentData() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) {
      state = const AgentDashboardState(errorMessage: 'User is not authenticated.');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final agentProfileRepo = ref.read(agentProfileRepositoryProvider);
      final assignmentRepo = ref.read(assignmentRepositoryProvider);

      final profile = await agentProfileRepo.getAgentProfile(user.id);
      final active = await assignmentRepo.getActiveAssignmentForAgent(user.id);
      final offers = await assignmentRepo.getOffersForAgent(user.id);
      final history = await assignmentRepo.getAgentAssignmentHistory(user.id);

      state = AgentDashboardState(
        isLoading: false,
        agentProfile: profile,
        activeAssignment: active,
        incomingOffers: offers,
        history: history,
      );

      // Auto-start location sharing ONLY if backend confirms active accepted job in assigned or in_progress state
      if (active != null &&
          active.status.isAccepted &&
          active.request != null &&
          (active.request!.status.isAssigned || active.request!.status.isInProgress)) {
        ref.read(agentLocationControllerProvider.notifier).startPublishingIfAuthorized(
              agentId: user.id,
              requestId: active.requestId,
            );
      } else {
        ref.read(agentLocationControllerProvider.notifier).stopPublishing();
      }

      // Initialize Realtime subscriptions
      _initRealtimeSubscription(user.id);
    } catch (e) {
      final message = ErrorHandler.getUserMessage(e);
      state = state.copyWith(isLoading: false, errorMessage: message);
    }
  }

  void _initRealtimeSubscription(String agentId) {
    final realtime = ref.read(realtimeServiceProvider);
    _offersChannel ??= realtime.subscribeToAgentOffers(
      agentId: agentId,
      onOfferChanged: (assignment) {
        loadAgentData();
      },
    );

    _requestsChannel ??= realtime.subscribeToAllRequests(
      onRequestChanged: () {
        loadAgentData();
      },
    );
  }

  Future<bool> setAvailability(bool available) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return false;

    final newStatus = available ? AgentAvailability.available : AgentAvailability.offline;
    try {
      final repo = ref.read(agentProfileRepositoryProvider);
      final updated = await repo.updateAvailability(user.id, newStatus);
      state = state.copyWith(agentProfile: updated);

      if (available) {
        ref.read(agentLocationControllerProvider.notifier).startPublishing(user.id);
      } else {
        ref.read(agentLocationControllerProvider.notifier).stopPublishing();
      }
      return true;
    } catch (e) {
      final message = ErrorHandler.getUserMessage(e);
      state = state.copyWith(errorMessage: message);
      return false;
    }
  }

  Future<bool> updateServiceRadius(double radiusKm) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return false;

    if (!ServiceRadiusConstants.isValid(radiusKm)) {
      state = state.copyWith(
        errorMessage:
            'Service radius must be between ${ServiceRadiusConstants.minRadiusKm.toInt()} and ${ServiceRadiusConstants.maxRadiusKm.toInt()} km.',
      );
      return false;
    }

    try {
      final repo = ref.read(agentProfileRepositoryProvider);
      final updated = await repo.updateServiceRadius(user.id, radiusKm);
      state = state.copyWith(agentProfile: updated);
      return true;
    } catch (e) {
      final message = ErrorHandler.getUserMessage(e);
      state = state.copyWith(errorMessage: message);
      return false;
    }
  }

  Future<bool> acceptOffer(String assignmentId, String requestId) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    try {
      final dispatchService = ref.read(dispatchServiceProvider);
      await dispatchService.acceptOffer(assignmentId);

      // Authoritative backend reload will verify assignment status and start GPS if authorized
      await loadAgentData();
      if (user != null) {
        ref.read(auditServiceProvider).logRequestAssigned(
          requestId,
          user.id,
          assignmentId: assignmentId,
        );
      }
      return true;
    } catch (e) {
      final message = ErrorHandler.getUserMessage(e);
      state = state.copyWith(errorMessage: message);
      await loadAgentData();
      return false;
    }
  }

  Future<bool> rejectOffer(String assignmentId, String requestId) async {

    try {
      final dispatchService = ref.read(dispatchServiceProvider);
      await dispatchService.rejectOffer(assignmentId);
      await loadAgentData();
      return true;
    } catch (e) {
      final message = ErrorHandler.getUserMessage(e);
      state = state.copyWith(errorMessage: message);
      await loadAgentData();
      return false;
    }
  }

  Future<bool> startService(String assignmentId, String requestId, {String? note}) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    try {
      final repo = ref.read(assignmentRepositoryProvider);
      await repo.startService(
        assignmentId: assignmentId,
        requestId: requestId,
        agentId: user?.id,
        note: note,
      );

      if (user != null) {
        ref.read(agentLocationControllerProvider.notifier).startPublishing(user.id);
        ref.read(auditServiceProvider).logRequestUpdated(
          requestId,
          'in_progress',
          actorId: user.id,
          note: note,
        );
      }

      await loadAgentData();
      return true;
    } catch (e) {
      final message = ErrorHandler.getUserMessage(e);
      state = state.copyWith(errorMessage: message);
      return false;
    }
  }

  Future<bool> completeService(String assignmentId, String requestId, {String? note}) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    try {
      final repo = ref.read(assignmentRepositoryProvider);
      await repo.completeService(
        assignmentId: assignmentId,
        requestId: requestId,
        agentId: user?.id,
        note: note,
      );

      // Stop live location publishing when job completes
      ref.read(agentLocationControllerProvider.notifier).stopPublishing();

      if (user != null) {
        ref.read(auditServiceProvider).logRequestUpdated(
          requestId,
          'completed',
          actorId: user.id,
          note: note,
        );
      }

      await loadAgentData();
      return true;
    } catch (e) {
      final message = ErrorHandler.getUserMessage(e);
      state = state.copyWith(errorMessage: message);
      return false;
    }
  }

  Future<bool> recordPayment({
    required String requestId,
    required String customerId,
    required double amount,
    String currency = 'INR',
    required PaymentMethod method,
    PaymentStatus status = PaymentStatus.paid,
  }) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return false;

    try {
      final repo = ref.read(paymentRepositoryProvider);
      await repo.recordPayment(
        requestId: requestId,
        customerId: customerId,
        agentId: user.id,
        amount: amount,
        currency: currency,
        method: method,
        status: status,
      );
      await loadAgentData();
      return true;
    } catch (e) {
      final message = ErrorHandler.getUserMessage(e);
      state = state.copyWith(errorMessage: message);
      return false;
    }
  }
}

final agentDashboardProvider =
    NotifierProvider<AgentDashboardController, AgentDashboardState>(
  AgentDashboardController.new,
);

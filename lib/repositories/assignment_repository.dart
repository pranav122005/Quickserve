import '../models/service_assignment.dart';

/// Contract for service assignment lifecycle operations.
abstract class AssignmentRepository {
  /// Retrieves pending offers for a specific agent.
  Future<List<ServiceAssignment>> getOffersForAgent(String agentId);

  /// Retrieves the active accepted assignment for an agent, if any.
  Future<ServiceAssignment?> getActiveAssignmentForAgent(String agentId);

  /// Retrieves assignment history for an agent.
  Future<List<ServiceAssignment>> getAgentAssignmentHistory(String agentId);

  /// Retrieves the latest assignment for a specific request.
  Future<ServiceAssignment?> getAssignmentForRequest(String requestId);

  /// Agent accepts an offered assignment.
  Future<void> acceptOffer({
    required String assignmentId,
    required String requestId,
    String? agentId,
  });

  /// Agent rejects an offered assignment.
  Future<void> rejectOffer({
    required String assignmentId,
    required String requestId,
    String? agentId,
  });

  /// Transitions an accepted assignment into in-progress service execution.
  Future<void> startService({
    required String assignmentId,
    required String requestId,
    String? agentId,
    String? note,
  });

  /// Completes the service.
  Future<void> completeService({
    required String assignmentId,
    required String requestId,
    String? agentId,
    String? note,
  });

  /// Admin manually assigns a request to an agent.
  Future<ServiceAssignment> manualAssign({
    required String requestId,
    required String agentId,
  });

}

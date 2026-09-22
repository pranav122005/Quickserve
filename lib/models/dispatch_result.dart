/// Represents the structured return value from the PostgreSQL dispatch RPC.
class DispatchResult {
  final bool success;
  final String? assignmentId;
  final String? agentId;
  final double? distanceMeters;
  final String? reason;
  final String? status;

  const DispatchResult({
    required this.success,
    this.assignmentId,
    this.agentId,
    this.distanceMeters,
    this.reason,
    this.status,
  });

  bool get isSuccess => success;
  bool get isOffered => success && assignmentId != null;
  bool get isNoAgentAvailable => reason == 'no_available_agent';
  bool get isUnauthorized => reason == 'unauthorized';
  bool get isNotDispatchable => reason == 'not_dispatchable';

  String get message {
    if (success) {
      if (assignmentId != null) {
        return 'Dispatch successful: Offer sent to agent.';
      }
      return 'Dispatch initiated.';
    }
    if (isNoAgentAvailable) return 'No available agents in service area.';
    if (isUnauthorized) return 'Unauthorized to dispatch this request.';
    if (isNotDispatchable) return 'Request is not in a dispatchable state.';
    return reason ?? 'Unknown dispatch error.';
  }

  factory DispatchResult.error(String message) {
    return DispatchResult(
      success: false,
      reason: message,
    );
  }

  factory DispatchResult.fromMap(Map<String, dynamic> map) {
    return DispatchResult(
      success: (map['success'] as bool?) ?? false,
      assignmentId: map['assignment_id'] as String?,
      agentId: map['agent_id'] as String?,
      distanceMeters: (map['distance_meters'] as num?)?.toDouble(),
      reason: map['reason'] as String?,
      status: map['status'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      if (assignmentId != null) 'assignment_id': assignmentId,
      if (agentId != null) 'agent_id': agentId,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (reason != null) 'reason': reason,
      if (status != null) 'status': status,
    };
  }

  @override
  String toString() =>
      'DispatchResult(success: $success, assignmentId: $assignmentId, reason: $reason)';
}

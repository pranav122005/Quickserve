import '../models/agent_location.dart';

abstract class AgentLocationRepository {
  /// Fetches the current location record for [agentId], or returns null if not available.
  Future<AgentLocation?> getAgentLocation(String agentId);

  /// Upserts the agent's current location in `agent_locations`.
  Future<void> updateCurrentLocation({
    required String agentId,
    required double latitude,
    required double longitude,
  });
}

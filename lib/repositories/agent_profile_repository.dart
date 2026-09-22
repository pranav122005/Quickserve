import '../models/agent_profile.dart';

abstract class AgentProfileRepository {
  Future<AgentProfile?> getAgentProfile(String agentId);
  Future<AgentProfile> updateAvailability(String agentId, AgentAvailability availability);
  Future<AgentProfile> updateServiceRadius(String agentId, double radiusKm);
  Future<List<AgentProfile>> getAllAgents();
}

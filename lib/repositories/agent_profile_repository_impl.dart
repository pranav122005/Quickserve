import 'agent_profile_repository.dart';
import '../models/agent_profile.dart';
import '../services/supabase_service.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';

class AgentProfileRepositoryImpl implements AgentProfileRepository {
  final SupabaseService _supabaseService;

  AgentProfileRepositoryImpl(this._supabaseService);

  @override
  Future<AgentProfile?> getAgentProfile(String agentId) async {
    final response = await _supabaseService.client
        .from(DbTables.agentProfiles)
        .select('*, profiles!agent_profiles_user_id_fkey(*)')
        .eq(DbColumns.userId, agentId)
        .maybeSingle();

    if (response == null) {
      // If agent profile row does not exist yet, create default
      try {
        final inserted = await _supabaseService.client
            .from(DbTables.agentProfiles)
            .insert({
              DbColumns.userId: agentId,
              DbColumns.serviceRadiusKm: 15.0,
              DbColumns.availability: AgentAvailability.offline.dbValue,
            })
            .select('*, profiles!agent_profiles_user_id_fkey(*)')
            .single();
        return AgentProfile.fromMap(inserted);
      } catch (_) {
        return null;
      }
    }

    return AgentProfile.fromMap(response);
  }

  @override
  Future<AgentProfile> updateAvailability(
    String agentId,
    AgentAvailability availability,
  ) async {
    final response = await _supabaseService.client
        .from(DbTables.agentProfiles)
        .update({DbColumns.availability: availability.dbValue})
        .eq(DbColumns.userId, agentId)
        .select('*, profiles!agent_profiles_user_id_fkey(*)')
        .single();

    return AgentProfile.fromMap(response);
  }

  @override
  Future<AgentProfile> updateServiceRadius(
    String agentId,
    double radiusKm,
  ) async {
    if (!ServiceRadiusConstants.isValid(radiusKm)) {
      throw ValidationException(
        'Service radius must be between ${ServiceRadiusConstants.minRadiusKm.toInt()} and ${ServiceRadiusConstants.maxRadiusKm.toInt()} km.',
      );
    }

    final response = await _supabaseService.client
        .from(DbTables.agentProfiles)
        .update({DbColumns.serviceRadiusKm: radiusKm})
        .eq(DbColumns.userId, agentId)
        .select('*, profiles!agent_profiles_user_id_fkey(*)')
        .single();

    return AgentProfile.fromMap(response);
  }

  @override
  Future<List<AgentProfile>> getAllAgents() async {
    final response = await _supabaseService.client
        .from(DbTables.agentProfiles)
        .select('*, profiles!agent_profiles_user_id_fkey(*)')
        .order(DbColumns.createdAt, ascending: false);

    final list = response as List;
    return list.map((item) => AgentProfile.fromMap(item as Map<String, dynamic>)).toList();
  }
}

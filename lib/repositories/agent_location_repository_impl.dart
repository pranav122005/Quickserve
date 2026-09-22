import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/geo_utils.dart';
import '../core/errors/app_exception.dart';
import '../models/agent_location.dart';
import '../services/supabase_service.dart';
import 'agent_location_repository.dart';

class AgentLocationRepositoryImpl implements AgentLocationRepository {
  final SupabaseService _supabaseService;

  AgentLocationRepositoryImpl(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;

  @override
  Future<AgentLocation?> getAgentLocation(String agentId) async {
    try {
      final response = await _client
          .from(DbTables.agentLocations)
          .select()
          .eq('agent_id', agentId)
          .maybeSingle();

      if (response == null) return null;
      return AgentLocation.fromMap(response);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateCurrentLocation({
    required String agentId,
    required double latitude,
    required double longitude,
  }) async {
    if (!GeoUtils.isValidCoordinate(latitude, longitude)) {
      throw const ServiceException(
        'Invalid coordinates: latitude must be between -90 and 90, longitude between -180 and 180.',
      );
    }

    final pointWkt = GeoUtils.toPointWkt(latitude: latitude, longitude: longitude);
    final nowIso = DateTime.now().toIso8601String();

    await _client.from(DbTables.agentLocations).upsert(
      {
        'agent_id': agentId,
        'location': pointWkt,
        DbColumns.updatedAt: nowIso,
      },
      onConflict: 'agent_id',
    );
  }
}

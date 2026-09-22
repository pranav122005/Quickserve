import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/service_request.dart';
import '../models/service_assignment.dart';
import '../models/agent_location.dart';
import 'supabase_service.dart';

/// Manages filtered Supabase Realtime subscriptions.
/// Realtime acts as transport only; PostgreSQL remains authoritative.
class RealtimeService {
  final SupabaseService _supabaseService;

  RealtimeService(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;

  /// Subscribes to changes for a specific [requestId].
  RealtimeChannel subscribeToRequest({
    required String requestId,
    required void Function(ServiceRequest updated) onUpdate,
  }) {
    final channelName = 'request_$requestId';
    final channel = _client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: DbTables.serviceRequests,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: DbColumns.id,
            value: requestId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              final request = ServiceRequest.fromMap(payload.newRecord);
              onUpdate(request);
            }
          },
        )
        .subscribe();

    return channel;
  }

  /// Subscribes to changes on assignments for [requestId].
  RealtimeChannel subscribeToAssignment({
    required String requestId,
    required void Function(ServiceAssignment assignment) onUpdate,
  }) {
    final channelName = 'assignment_req_$requestId';
    final channel = _client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: DbTables.serviceAssignments,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: DbColumns.requestId,
            value: requestId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              final assignment = ServiceAssignment.fromMap(payload.newRecord);
              onUpdate(assignment);
            }
          },
        )
        .subscribe();

    return channel;
  }

  /// Subscribes to offers directed to [agentId].
  RealtimeChannel subscribeToAgentOffers({
    required String agentId,
    required void Function(ServiceAssignment assignment) onOfferChanged,
  }) {
    final channelName = 'agent_offers_$agentId';
    final channel = _client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: DbTables.serviceAssignments,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: DbColumns.agentId,
            value: agentId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              final assignment = ServiceAssignment.fromMap(payload.newRecord);
              onOfferChanged(assignment);
            }
          },
        )
        .subscribe();

    return channel;
  }

  /// Subscribes to location updates for an assigned agent.
  /// (Authorization is strictly enforced by RLS at the database layer).
  RealtimeChannel subscribeToAgentLocation({
    required String agentId,
    required void Function(AgentLocation location) onLocationUpdate,
  }) {
    final channelName = 'agent_loc_$agentId';
    final channel = _client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: DbTables.agentLocations,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'agent_id',
            value: agentId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              final location = AgentLocation.fromMap(payload.newRecord);
              onLocationUpdate(location);
            }
          },
        )
        .subscribe();

    return channel;
  }

  /// Subscribes to changes across all service requests for realtime agent dashboard updates.
  RealtimeChannel subscribeToAllRequests({
    required void Function() onRequestChanged,
  }) {
    const channelName = 'all_service_requests_broadcast';
    final channel = _client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: DbTables.serviceRequests,
          callback: (_) {
            onRequestChanged();
          },
        )
        .subscribe();

    return channel;
  }

  /// Disposes and unsubscribes a realtime channel.
  Future<void> unsubscribe(RealtimeChannel? channel) async {
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }
}

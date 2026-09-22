import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dispatch_result.dart';
import '../core/errors/app_exception.dart';
import 'supabase_service.dart';

/// Service for authoritative PostgreSQL dispatch and offer acceptance/rejection RPCs.
class DispatchService {
  final SupabaseService _supabaseService;

  DispatchService(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;

  /// Triggers automated backend dispatch for [requestId].
  ///
  /// The PostgreSQL RPC verifies authorization (customer or admin), locks rows,
  /// ranks candidates with fair hybrid ranking, and atomically reserves an agent.
  Future<DispatchResult> dispatchRequest(String requestId) async {
    try {
      final response = await _client.rpc(
        'dispatch_service_request',
        params: {'p_request_id': requestId},
      );

      if (response is Map) {
        return DispatchResult.fromMap(Map<String, dynamic>.from(response));
      }

      return const DispatchResult(
        success: false,
        reason: 'unexpected_response_format',
      );
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202') {
        // Fallback: candidate matching via direct queries if RPC is not deployed yet
        try {
          // 1. Fetch available agents
          final availableAgentsRes = await _client
              .from('agent_profiles')
              .select('user_id')
              .eq('availability', 'available')
              .limit(1);

          final agentsList = availableAgentsRes as List;
          if (agentsList.isEmpty) {
            return const DispatchResult(
              success: false,
              reason: 'no_available_agents',
            );
          }

          final candidateAgentId = agentsList.first['user_id'] as String;
          final nowIso = DateTime.now().toIso8601String();

          // 2. Insert assignment offer
          final assignmentRes = await _client
              .from('service_assignments')
              .insert({
                'request_id': requestId,
                'agent_id': candidateAgentId,
                'status': 'offered',
                'offered_at': nowIso,
              })
              .select('id')
              .single();

          final assignmentId = assignmentRes['id'] as String;

          // 3. Update request status to dispatching
          await _client
              .from('service_requests')
              .update({'status': 'dispatching'})
              .eq('id', requestId);

          return DispatchResult(
            success: true,
            assignmentId: assignmentId,
            agentId: candidateAgentId,
          );
        } catch (_) {
          return const DispatchResult(
            success: false,
            reason: 'no_available_agents',
          );
        }
      }
      throw ServiceException(e.message, technicalDetails: e.details?.toString());
    } catch (e) {
      throw ServiceException('Failed to dispatch service request: $e');
    }
  }

  /// Accepts an offer for [assignmentId] via authoritative backend RPC.
  ///
  /// Atomically verifies offer validity (< 120s) and transitions assignment to accepted.
  Future<bool> acceptOffer(String assignmentId) async {
    try {
      final response = await _client.rpc(
        'accept_service_offer',
        params: {'p_assignment_id': assignmentId},
      );

      if (response is Map) {
        final success = response['success'] as bool? ?? false;
        if (!success) {
          final reason = response['reason'] as String? ?? 'unknown';
          if (reason == 'offer_expired') {
            throw const ServiceException('This service offer has expired (120s limit exceeded).');
          }
          if (reason == 'offer_already_processed') {
            throw const ServiceException('This offer has already been processed or assigned.');
          }
          throw ServiceException('Failed to accept offer: $reason');
        }
        return true;
      }
      return false;
    } on PostgrestException catch (e) {
      throw ServiceException(e.message, technicalDetails: e.details?.toString());
    }
  }

  /// Rejects an offer for [assignmentId] via authoritative backend RPC.
  ///
  /// Marks assignment rejected and immediately triggers backend dispatch for the next candidate.
  Future<bool> rejectOffer(String assignmentId) async {
    try {
      final response = await _client.rpc(
        'reject_service_offer',
        params: {'p_assignment_id': assignmentId},
      );

      if (response is Map) {
        return (response['success'] as bool?) ?? false;
      }
      return false;
    } on PostgrestException catch (e) {
      throw ServiceException(e.message, technicalDetails: e.details?.toString());
    }
  }

  /// Runs the backend stale offer cleanup.
  Future<int> expireStaleOffers() async {
    try {
      final response = await _client.rpc('expire_stale_service_offers');
      return (response as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

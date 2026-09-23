import 'package:supabase_flutter/supabase_flutter.dart';
import 'assignment_repository.dart';
import '../models/service_assignment.dart';
import '../models/service_request.dart';
import '../services/supabase_service.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';

class AssignmentRepositoryImpl implements AssignmentRepository {
  final SupabaseService _supabaseService;

  AssignmentRepositoryImpl(this._supabaseService);

  @override
  Future<List<ServiceAssignment>> getOffersForAgent(String agentId) async {
    final response = await _supabaseService.client
        .from(DbTables.serviceAssignments)
        .select('*, service_requests(*, profiles:customer_id(*))')
        .eq(DbColumns.agentId, agentId)
        .eq(DbColumns.status, AssignmentStatus.offered.dbValue)
        .order(DbColumns.createdAt, ascending: false);

    final list = response as List;
    return list.map((item) => ServiceAssignment.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<ServiceAssignment?> getActiveAssignmentForAgent(String agentId) async {
    final response = await _supabaseService.client
        .from(DbTables.serviceAssignments)
        .select('*, service_requests(*, profiles:customer_id(*))')
        .eq(DbColumns.agentId, agentId)
        .eq(DbColumns.status, AssignmentStatus.accepted.dbValue)
        .order(DbColumns.createdAt, ascending: false)
        .maybeSingle();

    if (response == null) return null;
    return ServiceAssignment.fromMap(response);
  }

  @override
  Future<List<ServiceAssignment>> getAgentAssignmentHistory(String agentId) async {
    final response = await _supabaseService.client
        .from(DbTables.serviceAssignments)
        .select('*, service_requests(*, profiles:customer_id(*))')
        .eq(DbColumns.agentId, agentId)
        .neq(DbColumns.status, AssignmentStatus.offered.dbValue)
        .order(DbColumns.createdAt, ascending: false);

    final list = response as List;
    return list.map((item) => ServiceAssignment.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<ServiceAssignment?> getAssignmentForRequest(String requestId) async {
    final response = await _supabaseService.client
        .from(DbTables.serviceAssignments)
        .select('*, profiles:agent_id(*)')
        .eq(DbColumns.requestId, requestId)
        .order(DbColumns.createdAt, ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return ServiceAssignment.fromMap(response);
  }

  @override
  Future<void> acceptOffer({
    required String assignmentId,
    required String requestId,
    String? agentId,
  }) async {
    final response = await _supabaseService.client.rpc(
      'accept_service_offer',
      params: {'p_assignment_id': assignmentId},
    );
    if (response is! Map || response['success'] != true) {
      throw const ServiceException('The service offer could not be accepted.');
    }
  }

  @override
  Future<void> rejectOffer({
    required String assignmentId,
    required String requestId,
    String? agentId,
  }) async {
    final response = await _supabaseService.client.rpc(
      'reject_service_offer',
      params: {'p_assignment_id': assignmentId},
    );
    if (response is! Map || response['success'] != true) {
      throw const ServiceException('The service offer could not be rejected.');
    }
  }

  @override
  Future<void> startService({
    required String assignmentId,
    required String requestId,
    String? agentId,
    String? note,
  }) async {
    final response = await _supabaseService.client.rpc(
      'start_service_assignment',
      params: {'p_assignment_id': assignmentId, 'p_note': note},
    );
    if (response is! Map || response['success'] != true) {
      throw const ServiceException('The service could not be started.');
    }
  }

  @override
  Future<void> completeService({
    required String assignmentId,
    required String requestId,
    String? agentId,
    String? note,
  }) async {
    final response = await _supabaseService.client.rpc(
      'complete_service_assignment',
      params: {'p_assignment_id': assignmentId, 'p_note': note},
    );
    if (response is! Map || response['success'] != true) {
      throw const ServiceException('The service could not be completed.');
    }
  }

  @override
  Future<ServiceAssignment> manualAssign({
    required String requestId,
    required String agentId,
  }) async {
    try {
      final response = await _supabaseService.client.rpc(
        'admin_assign_service_request',
        params: {
          'p_request_id': requestId,
          'p_agent_id': agentId,
        },
      );

      if (response is Map) {
        final map = Map<String, dynamic>.from(response);
        final success = map['success'] as bool? ?? false;
        if (!success) {
          final reason = map['reason'] as String? ?? 'unknown';
          if (reason == 'unauthorized_not_admin') {
            throw const ServiceException(
              'Your logged in user account does not have Admin privileges. Please sign in as Admin (admin@quickserve.com) to assign agents.',
            );
          }
          final message = map['message'] as String? ?? 'Admin assignment failed ($reason).';
          throw ServiceException(message);
        }
      }
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const ServiceException(
          'Your logged in user account does not have Admin privileges. Please sign in as Admin (admin@quickserve.com) to assign agents.',
        );
      } else {
        rethrow;
      }
    }

    final createdAssignment = await getAssignmentForRequest(requestId);
    if (createdAssignment != null) {
      return createdAssignment;
    }

    throw const ServiceException('Failed to complete manual assignment.');
  }

}

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
    final nowIso = DateTime.now().toIso8601String();

    try {
      final response = await _supabaseService.client.rpc(
        'accept_service_offer',
        params: {'p_assignment_id': assignmentId},
      );
      if (response is Map) {
        final success = response['success'] as bool? ?? false;
        if (success) return;
      }
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202') rethrow;
    }

    // Direct DB Fallback
    await _supabaseService.client
        .from(DbTables.serviceAssignments)
        .update({
          DbColumns.status: AssignmentStatus.accepted.dbValue,
          DbColumns.acceptedAt: nowIso,
        })
        .eq(DbColumns.id, assignmentId);

    await _supabaseService.client
        .from(DbTables.serviceRequests)
        .update({DbColumns.status: RequestStatus.assigned.dbValue})
        .eq(DbColumns.id, requestId);

    try {
      await _supabaseService.client.from(DbTables.requestStatusHistory).insert({
        DbColumns.requestId: requestId,
        DbColumns.oldStatus: RequestStatus.dispatching.dbValue,
        DbColumns.newStatus: RequestStatus.assigned.dbValue,
        DbColumns.changedBy: agentId ?? _supabaseService.client.auth.currentUser?.id,
        DbColumns.note: 'Offer accepted by service agent.',
      });
    } catch (_) {}
  }

  @override
  Future<void> rejectOffer({
    required String assignmentId,
    required String requestId,
    String? agentId,
  }) async {
    final nowIso = DateTime.now().toIso8601String();

    try {
      final response = await _supabaseService.client.rpc(
        'reject_service_offer',
        params: {'p_assignment_id': assignmentId},
      );
      if (response is Map) {
        final success = response['success'] as bool? ?? false;
        if (success) return;
      }
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202') rethrow;
    }

    // Direct DB Fallback
    await _supabaseService.client
        .from(DbTables.serviceAssignments)
        .update({
          DbColumns.status: AssignmentStatus.rejected.dbValue,
          DbColumns.rejectedAt: nowIso,
        })
        .eq(DbColumns.id, assignmentId);

    await _supabaseService.client
        .from(DbTables.serviceRequests)
        .update({DbColumns.status: RequestStatus.pending.dbValue})
        .eq(DbColumns.id, requestId);

    try {
      await _supabaseService.client.from(DbTables.requestStatusHistory).insert({
        DbColumns.requestId: requestId,
        DbColumns.oldStatus: RequestStatus.dispatching.dbValue,
        DbColumns.newStatus: RequestStatus.pending.dbValue,
        DbColumns.changedBy: agentId ?? _supabaseService.client.auth.currentUser?.id,
        DbColumns.note: 'Offer declined by agent.',
      });
    } catch (_) {}
  }

  @override
  Future<void> startService({
    required String assignmentId,
    required String requestId,
    String? agentId,
    String? note,
  }) async {
    // Assignment remains 'accepted' (no in_progress in assignment schema)
    // Request becomes 'in_progress'
    await _supabaseService.client
        .from(DbTables.serviceRequests)
        .update({DbColumns.status: RequestStatus.inProgress.dbValue})
        .eq(DbColumns.id, requestId);

    try {
      await _supabaseService.client.from(DbTables.requestStatusHistory).insert({
        DbColumns.requestId: requestId,
        DbColumns.oldStatus: RequestStatus.assigned.dbValue,
        DbColumns.newStatus: RequestStatus.inProgress.dbValue,
        DbColumns.changedBy: agentId,
        DbColumns.note: note ?? 'Service initiated on-site by agent.',
      });
    } catch (_) {}
  }

  @override
  Future<void> completeService({
    required String assignmentId,
    required String requestId,
    String? agentId,
    String? note,
  }) async {
    final nowIso = DateTime.now().toIso8601String();

    // 1. Complete assignment
    await _supabaseService.client
        .from(DbTables.serviceAssignments)
        .update({
          DbColumns.status: AssignmentStatus.completed.dbValue,
          DbColumns.completedAt: nowIso,
        })
        .eq(DbColumns.id, assignmentId);

    // 2. Complete request
    await _supabaseService.client
        .from(DbTables.serviceRequests)
        .update({DbColumns.status: RequestStatus.completed.dbValue})
        .eq(DbColumns.id, requestId);

    // 3. Record history
    try {
      await _supabaseService.client.from(DbTables.requestStatusHistory).insert({
        DbColumns.requestId: requestId,
        DbColumns.oldStatus: RequestStatus.inProgress.dbValue,
        DbColumns.newStatus: RequestStatus.completed.dbValue,
        DbColumns.changedBy: agentId,
        DbColumns.note: note ?? 'Service successfully completed by agent.',
      });
    } catch (_) {}
  }

  @override
  Future<ServiceAssignment> manualAssign({
    required String requestId,
    required String agentId,
  }) async {
    final nowIso = DateTime.now().toIso8601String();

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
      if (e.code == 'PGRST202') {
        // Fallback to direct DB insert if RPC is missing
        try {
          await _supabaseService.client.from(DbTables.serviceAssignments).insert({
            DbColumns.requestId: requestId,
            DbColumns.agentId: agentId,
            DbColumns.status: AssignmentStatus.offered.dbValue,
            DbColumns.offeredAt: nowIso,
          });

          await _supabaseService.client
              .from(DbTables.serviceRequests)
              .update({DbColumns.status: RequestStatus.dispatching.dbValue})
              .eq(DbColumns.id, requestId);
        } on PostgrestException catch (fallbackErr) {
          if (fallbackErr.code == '42501') {
            throw const ServiceException(
              'Your logged in user account does not have Admin privileges. Please sign in as Admin (admin@quickserve.com) to assign agents.',
            );
          }
          rethrow;
        }
      } else if (e.code == '42501') {
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

  @override
  Future<ServiceAssignment> claimPendingRequest({
    required String requestId,
    required String agentId,
  }) async {
    final nowIso = DateTime.now().toIso8601String();

    Map<String, dynamic> assignmentData;
    try {
      assignmentData = await _supabaseService.client
          .from(DbTables.serviceAssignments)
          .insert({
            DbColumns.requestId: requestId,
            DbColumns.agentId: agentId,
            DbColumns.status: AssignmentStatus.accepted.dbValue,
            DbColumns.offeredAt: nowIso,
            DbColumns.acceptedAt: nowIso,
          })
          .select()
          .single();
    } catch (_) {
      final res = await _supabaseService.client
          .from(DbTables.serviceAssignments)
          .insert({
            DbColumns.requestId: requestId,
            DbColumns.agentId: agentId,
            DbColumns.status: AssignmentStatus.accepted.dbValue,
            DbColumns.offeredAt: nowIso,
            DbColumns.acceptedAt: nowIso,
          })
          .select();
      assignmentData = (res as List).first as Map<String, dynamic>;
    }

    try {
      await _supabaseService.client
          .from(DbTables.serviceRequests)
          .update({DbColumns.status: RequestStatus.assigned.dbValue})
          .eq(DbColumns.id, requestId);
    } catch (_) {}

    try {
      await _supabaseService.client.from(DbTables.requestStatusHistory).insert({
        DbColumns.requestId: requestId,
        DbColumns.oldStatus: RequestStatus.pending.dbValue,
        DbColumns.newStatus: RequestStatus.assigned.dbValue,
        DbColumns.changedBy: agentId,
        DbColumns.note: 'Agent claimed and accepted service request.',
      });
    } catch (_) {}

    return ServiceAssignment.fromMap(assignmentData);
  }
}

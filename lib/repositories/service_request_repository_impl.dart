import 'service_request_repository.dart';
import '../models/service_request.dart';
import '../services/supabase_service.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/geo_utils.dart';
import '../core/errors/app_exception.dart';

class ServiceRequestRepositoryImpl implements ServiceRequestRepository {
  final SupabaseService _supabaseService;

  ServiceRequestRepositoryImpl(this._supabaseService);

  @override
  Future<ServiceRequest> createRequest({
    required String customerId,
    required String category,
    required String title,
    String? description,
    required String serviceAddress,
    required RequestPriority priority,
    double? latitude,
    double? longitude,
  }) async {
    final String cleanTitle = title.trim();
    final String cleanAddress = serviceAddress.trim().isNotEmpty ? serviceAddress.trim() : 'Address not specified';
    final String cleanDescription = (description != null && description.trim().isNotEmpty)
        ? description.trim()
        : cleanTitle;

    final data = <String, dynamic>{
      DbColumns.customerId: customerId,
      DbColumns.category: category,
      DbColumns.title: cleanTitle,
      DbColumns.description: cleanDescription,
      DbColumns.serviceAddress: cleanAddress,
      DbColumns.priority: priority.dbValue,
      DbColumns.status: RequestStatus.pending.dbValue,
    };

    final double finalLat = (latitude != null && GeoUtils.isValidLatitude(latitude)) ? latitude : 12.9716;
    final double finalLon = (longitude != null && GeoUtils.isValidLongitude(longitude)) ? longitude : 77.6412;
    data[DbColumns.serviceLocation] = GeoUtils.toPointWkt(latitude: finalLat, longitude: finalLon);

    final response = await _supabaseService.client
        .from(DbTables.serviceRequests)
        .insert(data)
        .select()
        .single();

    final request = ServiceRequest.fromMap(response);

    // Record initial status history entry if schema/RLS permits
    try {
      await _supabaseService.client.from(DbTables.requestStatusHistory).insert({
        DbColumns.requestId: request.id,
        DbColumns.oldStatus: null,
        DbColumns.newStatus: RequestStatus.pending.dbValue,
        DbColumns.changedBy: customerId,
        DbColumns.note: 'Request created by customer.',
      });
    } catch (_) {
      // Non-fatal: if RLS or DB trigger manages history, proceed cleanly
    }

    return request;
  }

  @override
  Future<List<ServiceRequest>> getCustomerRequests(String customerId) async {
    final response = await _supabaseService.client
        .from(DbTables.serviceRequests)
        .select()
        .eq(DbColumns.customerId, customerId)
        .order(DbColumns.createdAt, ascending: false);

    final list = response as List;
    return list.map((item) => ServiceRequest.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<ServiceRequest> getRequestById(String requestId) async {
    final response = await _supabaseService.client
        .from(DbTables.serviceRequests)
        .select('*, profiles:customer_id(*)')
        .eq(DbColumns.id, requestId)
        .maybeSingle();

    if (response == null) {
      throw const ServiceException('Service request not found.');
    }

    return ServiceRequest.fromMap(response);
  }

  @override
  Future<void> cancelRequest(String requestId, {String? changedBy}) async {
    // 1. Check current status
    final current = await getRequestById(requestId);
    if (!current.status.canBeCancelledByCustomer) {
      throw ServiceException(
        'Cannot cancel request with status "${current.status.displayName}". '
        'Only pending, dispatching, or assigned requests can be cancelled.',
      );
    }

    // 2. Update status
    await _supabaseService.client
        .from(DbTables.serviceRequests)
        .update({DbColumns.status: RequestStatus.cancelled.dbValue})
        .eq(DbColumns.id, requestId);

    // 3. Record status history
    try {
      await _supabaseService.client.from(DbTables.requestStatusHistory).insert({
        DbColumns.requestId: requestId,
        DbColumns.oldStatus: current.status.dbValue,
        DbColumns.newStatus: RequestStatus.cancelled.dbValue,
        DbColumns.changedBy: changedBy,
        DbColumns.note: 'Cancelled by customer.',
      });
    } catch (_) {}
  }

  @override
  Future<List<ServiceRequest>> getAllRequests({RequestStatus? statusFilter}) async {
    try {
      var query = _supabaseService.client
          .from(DbTables.serviceRequests)
          .select('*, profiles:customer_id(*)');

      if (statusFilter != null) {
        query = query.eq(DbColumns.status, statusFilter.dbValue);
      }

      final response = await query.order(DbColumns.createdAt, ascending: false);
      final list = response as List;
      return list.map((item) => ServiceRequest.fromMap(item as Map<String, dynamic>)).toList();
    } catch (_) {
      // Fallback: fetch service_requests directly without joined profiles table
      try {
        var query = _supabaseService.client
            .from(DbTables.serviceRequests)
            .select();

        if (statusFilter != null) {
          query = query.eq(DbColumns.status, statusFilter.dbValue);
        }

        final response = await query.order(DbColumns.createdAt, ascending: false);
        final list = response as List;
        return list.map((item) => ServiceRequest.fromMap(item as Map<String, dynamic>)).toList();
      } catch (_) {
        return [];
      }
    }
  }

  @override
  Future<void> updateRequestStatus({
    required String requestId,
    required RequestStatus newStatus,
    RequestStatus? oldStatus,
    String? changedBy,
    String? note,
  }) async {
    await _supabaseService.client
        .from(DbTables.serviceRequests)
        .update({DbColumns.status: newStatus.dbValue})
        .eq(DbColumns.id, requestId);

    try {
      await _supabaseService.client.from(DbTables.requestStatusHistory).insert({
        DbColumns.requestId: requestId,
        if (oldStatus != null) DbColumns.oldStatus: oldStatus.dbValue,
        DbColumns.newStatus: newStatus.dbValue,
        DbColumns.changedBy: changedBy,
        DbColumns.note: note,
      });
    } catch (_) {}
  }

  @override
  Future<void> updateEstimatedArrival({
    required String requestId,
    required DateTime estimatedArrival,
  }) async {
    // Check current request lifecycle status
    final current = await getRequestById(requestId);
    if (current.status.isCompleted || current.status.isCancelled) {
      throw ServiceException(
        'Cannot update ETA for a ${current.status.displayName.toLowerCase()} request.',
      );
    }

    try {
      final res = await _supabaseService.client.rpc(
        'update_service_request_eta',
        params: {
          'p_request_id': requestId,
          'p_estimated_arrival': estimatedArrival.toIso8601String(),
        },
      );
      if (res is Map && res['success'] == false) {
        final reason = res['reason']?.toString() ?? 'Unauthorized or invalid state';
        throw ServiceException('ETA update failed: $reason');
      }
    } catch (e) {
      if (e is ServiceException) rethrow;
      // Direct update fallback when RPC is unavailable in mock environment
      try {
        await _supabaseService.client
            .from(DbTables.serviceRequests)
            .update({
              DbColumns.estimatedArrival: estimatedArrival.toIso8601String(),
              DbColumns.updatedAt: DateTime.now().toIso8601String(),
            })
            .eq(DbColumns.id, requestId);
      } catch (innerErr) {
        throw const ServiceException('Unable to update ETA. Please try again.');
      }
    }
  }
}

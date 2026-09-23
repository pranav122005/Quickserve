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
    final data = <String, dynamic>{
      DbColumns.customerId: customerId,
      DbColumns.category: category,
      DbColumns.title: title.trim(),
      DbColumns.serviceAddress: serviceAddress.trim(),
      DbColumns.priority: priority.dbValue,
      DbColumns.status: RequestStatus.pending.dbValue,
    };

    if (description != null && description.trim().isNotEmpty) {
      data[DbColumns.description] = description.trim();
    }

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
}

import 'status_history_repository.dart';
import '../models/request_status_history.dart';
import '../models/service_request.dart';
import '../services/supabase_service.dart';
import '../core/constants/app_constants.dart';

class StatusHistoryRepositoryImpl implements StatusHistoryRepository {
  final SupabaseService _supabaseService;

  StatusHistoryRepositoryImpl(this._supabaseService);

  @override
  Future<List<RequestStatusHistory>> getHistoryForRequest(String requestId) async {
    final response = await _supabaseService.client
        .from(DbTables.requestStatusHistory)
        .select()
        .eq(DbColumns.requestId, requestId)
        .order(DbColumns.createdAt, ascending: true);

    final list = response as List;
    return list.map((item) => RequestStatusHistory.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> addHistoryEntry({
    required String requestId,
    RequestStatus? oldStatus,
    required RequestStatus newStatus,
    String? changedBy,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      DbColumns.requestId: requestId,
      DbColumns.newStatus: newStatus.dbValue,
    };
    if (oldStatus != null) payload[DbColumns.oldStatus] = oldStatus.dbValue;
    if (changedBy != null) payload[DbColumns.changedBy] = changedBy;
    if (note != null) payload[DbColumns.note] = note;

    await _supabaseService.client.from(DbTables.requestStatusHistory).insert(payload);
  }
}

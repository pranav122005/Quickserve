import '../models/request_status_history.dart';
import '../models/service_request.dart';

abstract class StatusHistoryRepository {
  Future<List<RequestStatusHistory>> getHistoryForRequest(String requestId);
  Future<void> addHistoryEntry({
    required String requestId,
    RequestStatus? oldStatus,
    required RequestStatus newStatus,
    String? changedBy,
    String? note,
  });
}

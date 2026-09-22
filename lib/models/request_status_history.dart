import '../core/constants/app_constants.dart';
import 'service_request.dart';

/// Represents an entry in the `public.request_status_history` table.
class RequestStatusHistory {
  final dynamic id;
  final String requestId;
  final RequestStatus? oldStatus;
  final RequestStatus newStatus;
  final String? changedBy;
  final String? note;
  final DateTime? createdAt;

  const RequestStatusHistory({
    required this.id,
    required this.requestId,
    this.oldStatus,
    required this.newStatus,
    this.changedBy,
    this.note,
    this.createdAt,
  });

  factory RequestStatusHistory.fromMap(Map<String, dynamic> map) {
    return RequestStatusHistory(
      id: map[DbColumns.id],
      requestId: map[DbColumns.requestId] as String,
      oldStatus: map[DbColumns.oldStatus] != null
          ? RequestStatus.fromString(map[DbColumns.oldStatus] as String)
          : null,
      newStatus: RequestStatus.fromString(map[DbColumns.newStatus] as String?),
      changedBy: map[DbColumns.changedBy] as String?,
      note: map[DbColumns.note] as String?,
      createdAt: map[DbColumns.createdAt] != null
          ? DateTime.tryParse(map[DbColumns.createdAt] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      DbColumns.requestId: requestId,
      if (oldStatus != null) DbColumns.oldStatus: oldStatus!.dbValue,
      DbColumns.newStatus: newStatus.dbValue,
      if (changedBy != null) DbColumns.changedBy: changedBy,
      if (note != null) DbColumns.note: note,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestStatusHistory &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          requestId == other.requestId &&
          newStatus == other.newStatus;

  @override
  int get hashCode => id.hashCode ^ requestId.hashCode ^ newStatus.hashCode;
}

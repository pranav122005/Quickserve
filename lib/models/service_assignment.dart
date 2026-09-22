import '../core/constants/app_constants.dart';
import 'service_request.dart';
import 'user_profile.dart';

/// Supported assignment statuses in the database schema.
/// Schema statuses: offered, accepted, rejected, cancelled, completed.
enum AssignmentStatus {
  offered('offered', 'Offered'),
  accepted('accepted', 'Accepted'),
  rejected('rejected', 'Rejected'),
  cancelled('cancelled', 'Cancelled'),
  completed('completed', 'Completed');

  final String dbValue;
  final String displayName;

  const AssignmentStatus(this.dbValue, this.displayName);

  bool get isOffered => this == AssignmentStatus.offered;
  bool get isAccepted => this == AssignmentStatus.accepted;
  bool get isRejected => this == AssignmentStatus.rejected;
  bool get isCancelled => this == AssignmentStatus.cancelled;
  bool get isCompleted => this == AssignmentStatus.completed;

  static AssignmentStatus fromString(String? value) {
    if (value == null) return AssignmentStatus.offered;
    final normalized = value.trim().toLowerCase();
    for (final s in AssignmentStatus.values) {
      if (s.dbValue == normalized) return s;
    }
    return AssignmentStatus.offered;
  }
}

/// Represents a record in the `public.service_assignments` table.
class ServiceAssignment {
  final String id;
  final String requestId;
  final String agentId;
  final AssignmentStatus status;
  final DateTime? offeredAt;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final ServiceRequest? request;
  final UserProfile? agentProfile;

  const ServiceAssignment({
    required this.id,
    required this.requestId,
    required this.agentId,
    required this.status,
    this.offeredAt,
    this.acceptedAt,
    this.rejectedAt,
    this.completedAt,
    this.createdAt,
    this.request,
    this.agentProfile,
  });

  /// Checks if an offered assignment has exceeded the 120s response window.
  bool isOfferExpired({DateTime? referenceTime, int windowSeconds = 120}) {
    if (!status.isOffered || offeredAt == null) return false;
    final now = referenceTime ?? DateTime.now();
    return now.difference(offeredAt!).inSeconds >= windowSeconds;
  }

  /// Calculates the remaining seconds before the offer window expires (between 0 and 120).
  int remainingOfferSeconds({DateTime? referenceTime, int windowSeconds = 120}) {
    if (!status.isOffered || offeredAt == null) return 0;
    final now = referenceTime ?? DateTime.now();
    final elapsed = now.difference(offeredAt!).inSeconds;
    final remaining = windowSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  factory ServiceAssignment.fromMap(Map<String, dynamic> map) {
    ServiceRequest? joinedRequest;
    if (map['service_requests'] is Map<String, dynamic>) {
      joinedRequest = ServiceRequest.fromMap(map['service_requests'] as Map<String, dynamic>);
    }

    UserProfile? joinedAgent;
    if (map['profiles'] is Map<String, dynamic>) {
      joinedAgent = UserProfile.fromMap(map['profiles'] as Map<String, dynamic>);
    }

    return ServiceAssignment(
      id: map[DbColumns.id] as String,
      requestId: map[DbColumns.requestId] as String,
      agentId: map[DbColumns.agentId] as String,
      status: AssignmentStatus.fromString(map[DbColumns.status] as String?),
      offeredAt: map[DbColumns.offeredAt] != null
          ? DateTime.tryParse(map[DbColumns.offeredAt] as String)
          : null,
      acceptedAt: map[DbColumns.acceptedAt] != null
          ? DateTime.tryParse(map[DbColumns.acceptedAt] as String)
          : null,
      rejectedAt: map[DbColumns.rejectedAt] != null
          ? DateTime.tryParse(map[DbColumns.rejectedAt] as String)
          : null,
      completedAt: map[DbColumns.completedAt] != null
          ? DateTime.tryParse(map[DbColumns.completedAt] as String)
          : null,
      createdAt: map[DbColumns.createdAt] != null
          ? DateTime.tryParse(map[DbColumns.createdAt] as String)
          : null,
      request: joinedRequest,
      agentProfile: joinedAgent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DbColumns.requestId: requestId,
      DbColumns.agentId: agentId,
      DbColumns.status: status.dbValue,
      if (offeredAt != null) DbColumns.offeredAt: offeredAt!.toIso8601String(),
      if (acceptedAt != null) DbColumns.acceptedAt: acceptedAt!.toIso8601String(),
      if (rejectedAt != null) DbColumns.rejectedAt: rejectedAt!.toIso8601String(),
      if (completedAt != null) DbColumns.completedAt: completedAt!.toIso8601String(),
    };
  }

  ServiceAssignment copyWith({
    String? id,
    String? requestId,
    String? agentId,
    AssignmentStatus? status,
    DateTime? offeredAt,
    DateTime? acceptedAt,
    DateTime? rejectedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    ServiceRequest? request,
    UserProfile? agentProfile,
  }) {
    return ServiceAssignment(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      agentId: agentId ?? this.agentId,
      status: status ?? this.status,
      offeredAt: offeredAt ?? this.offeredAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      request: request ?? this.request,
      agentProfile: agentProfile ?? this.agentProfile,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceAssignment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          status == other.status;

  @override
  int get hashCode => id.hashCode ^ status.hashCode;
}

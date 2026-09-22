import '../core/constants/app_constants.dart';
import '../core/utils/geo_utils.dart';
import '../core/utils/formatters.dart';
import 'user_profile.dart';

/// Supported service request priorities.
/// The database schema uses: low, normal, high, urgent.
enum RequestPriority {
  low('low', 'Low'),
  normal('normal', 'Medium'),
  high('high', 'High'),
  urgent('urgent', 'Urgent');

  final String dbValue;
  final String displayName;

  const RequestPriority(this.dbValue, this.displayName);

  static RequestPriority fromString(String? value) {
    if (value == null) return RequestPriority.normal;
    final normalized = value.trim().toLowerCase();
    for (final p in RequestPriority.values) {
      if (p.dbValue == normalized) return p;
    }
    return RequestPriority.normal;
  }
}

/// Lifecycle states of a QuickServe service request.
enum RequestStatus {
  pending('pending', 'Pending'),
  dispatching('dispatching', 'Dispatching'),
  assigned('assigned', 'Assigned'),
  inProgress('in_progress', 'In Progress'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  final String dbValue;
  final String displayName;

  const RequestStatus(this.dbValue, this.displayName);

  bool get isPending => this == RequestStatus.pending;
  bool get isDispatching => this == RequestStatus.dispatching;
  bool get isAssigned => this == RequestStatus.assigned;
  bool get isInProgress => this == RequestStatus.inProgress;
  bool get isCompleted => this == RequestStatus.completed;
  bool get isCancelled => this == RequestStatus.cancelled;

  /// Whether the request is actively in the workflow (not completed or cancelled)
  bool get isActive =>
      this == RequestStatus.pending ||
      this == RequestStatus.dispatching ||
      this == RequestStatus.assigned ||
      this == RequestStatus.inProgress;

  /// Customers can cancel requests before they are completed, cancelled, or actively in-progress.
  bool get canBeCancelledByCustomer =>
      this == RequestStatus.pending ||
      this == RequestStatus.dispatching ||
      this == RequestStatus.assigned;

  static RequestStatus fromString(String? value) {
    if (value == null) return RequestStatus.pending;
    final normalized = value.trim().toLowerCase();
    for (final s in RequestStatus.values) {
      if (s.dbValue == normalized) return s;
    }
    return RequestStatus.pending;
  }
}

/// Represents a record in the `public.service_requests` table.
class ServiceRequest {
  final String id;
  final String customerId;
  final String category;
  final String title;
  final String? description;
  final String serviceAddress;
  final RequestPriority priority;
  final RequestStatus status;
  final GeoPoint? location;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final UserProfile? customerProfile;

  /// Human-readable unique request ID similar to REQ-2026-000123.
  String get formattedId => Formatters.formatRequestId(id, createdAt);

  const ServiceRequest({
    required this.id,
    required this.customerId,
    required this.category,
    required this.title,
    this.description,
    required this.serviceAddress,
    required this.priority,
    required this.status,
    this.location,
    this.createdAt,
    this.updatedAt,
    this.customerProfile,
  });

  factory ServiceRequest.fromMap(Map<String, dynamic> map) {
    UserProfile? joinedCustomer;
    if (map['profiles'] is Map<String, dynamic>) {
      joinedCustomer = UserProfile.fromMap(map['profiles'] as Map<String, dynamic>);
    }

    return ServiceRequest(
      id: map[DbColumns.id] as String,
      customerId: map[DbColumns.customerId] as String,
      category: (map[DbColumns.category] as String?) ?? 'Other',
      title: (map[DbColumns.title] as String?) ?? '',
      description: map[DbColumns.description] as String?,
      serviceAddress: (map[DbColumns.serviceAddress] as String?) ?? '',
      priority: RequestPriority.fromString(map[DbColumns.priority] as String?),
      status: RequestStatus.fromString(map[DbColumns.status] as String?),
      location: GeoUtils.parsePoint(map[DbColumns.serviceLocation]),
      createdAt: map[DbColumns.createdAt] != null
          ? DateTime.tryParse(map[DbColumns.createdAt] as String)
          : null,
      updatedAt: map[DbColumns.updatedAt] != null
          ? DateTime.tryParse(map[DbColumns.updatedAt] as String)
          : null,
      customerProfile: joinedCustomer,
    );
  }

  Map<String, dynamic> toInsertMap() {
    final data = <String, dynamic>{
      DbColumns.customerId: customerId,
      DbColumns.category: category,
      DbColumns.title: title,
      DbColumns.serviceAddress: serviceAddress,
      DbColumns.priority: priority.dbValue,
      DbColumns.status: status.dbValue,
    };
    if (description != null && description!.trim().isNotEmpty) {
      data[DbColumns.description] = description!.trim();
    }
    if (location != null) {
      data[DbColumns.serviceLocation] = location!.toWkt();
    }
    return data;
  }

  Map<String, dynamic> toMap() => toInsertMap();

  ServiceRequest copyWith({
    String? id,
    String? customerId,
    String? category,
    String? title,
    String? description,
    String? serviceAddress,
    RequestPriority? priority,
    RequestStatus? status,
    GeoPoint? location,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserProfile? customerProfile,
  }) {
    return ServiceRequest(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      serviceAddress: serviceAddress ?? this.serviceAddress,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customerProfile: customerProfile ?? this.customerProfile,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceRequest &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          status == other.status &&
          priority == other.priority;

  @override
  int get hashCode => id.hashCode ^ status.hashCode ^ priority.hashCode;
}

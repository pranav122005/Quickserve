import '../models/service_request.dart';

/// Contract for service request operations.
abstract class ServiceRequestRepository {
  /// Creates a new service request.
  Future<ServiceRequest> createRequest({
    required String customerId,
    required String category,
    required String title,
    String? description,
    required String serviceAddress,
    required RequestPriority priority,
    double? latitude,
    double? longitude,
  });

  /// Retrieves all service requests created by a specific customer.
  Future<List<ServiceRequest>> getCustomerRequests(String customerId);

  /// Retrieves a specific service request by ID.
  Future<ServiceRequest> getRequestById(String requestId);

  /// Cancels an existing service request by customer.
  Future<void> cancelRequest(String requestId, {String? changedBy});

  /// Retrieves all service requests for admin monitoring.
  Future<List<ServiceRequest>> getAllRequests({RequestStatus? statusFilter});

  /// Updates the lifecycle status of a service request.
  Future<void> updateRequestStatus({
    required String requestId,
    required RequestStatus newStatus,
    RequestStatus? oldStatus,
    String? changedBy,
    String? note,
  });
}

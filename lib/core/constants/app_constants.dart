/// Application-wide constants for routing, database tables, roles, and status enums.
class AppRoutes {
  static const String root = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String customer = '/customer';
  static const String agent = '/agent';
  static const String admin = '/admin';
  static const String unauthorized = '/unauthorized';
}

class DbTables {
  static const String profiles = 'profiles';
  static const String agentProfiles = 'agent_profiles';
  static const String serviceRequests = 'service_requests';
  static const String serviceAssignments = 'service_assignments';
  static const String requestStatusHistory = 'request_status_history';
  static const String payments = 'payments';
  static const String agentLocations = 'agent_locations';
  static const String notifications = 'notifications';
}

class DbColumns {
  // Common
  static const String id = 'id';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
  static const String status = 'status';

  // Profiles
  static const String fullName = 'full_name';
  static const String phone = 'phone';
  static const String role = 'role';

  // Agent Profiles
  static const String userId = 'user_id';
  static const String serviceRadiusKm = 'service_radius_km';
  static const String availability = 'availability';
  static const String isVerified = 'is_verified';

  // Service Requests
  static const String customerId = 'customer_id';
  static const String category = 'category';
  static const String title = 'title';
  static const String description = 'description';
  static const String serviceAddress = 'service_address';
  static const String priority = 'priority';
  static const String serviceLocation = 'service_location';

  // Service Assignments
  static const String requestId = 'request_id';
  static const String agentId = 'agent_id';
  static const String offeredAt = 'offered_at';
  static const String acceptedAt = 'accepted_at';
  static const String rejectedAt = 'rejected_at';
  static const String completedAt = 'completed_at';

  // Status History
  static const String oldStatus = 'old_status';
  static const String newStatus = 'new_status';
  static const String changedBy = 'changed_by';
  static const String note = 'note';

  // Payments
  static const String amount = 'amount';
  static const String currency = 'currency';
  static const String method = 'method';
  static const String paidAt = 'paid_at';
}

class ServiceCategories {
  static const List<String> all = [
    'AC Servicing',
    'Plumbing',
    'Electrical',
    'Cleaning',
    'Appliance Repair',
    'Carpentry',
    'Painting',
    'Pest Control',
    'General Maintenance',
    'Other',
  ];
}

/// Authoritative service radius constraints established by the QuickServe platform.
/// Agents can configure coverage strictly within 10 km to 20 km.
class ServiceRadiusConstants {
  static const double minRadiusKm = 10.0;
  static const double maxRadiusKm = 20.0;
  static const double defaultRadiusKm = 15.0;

  /// Returns true if the radius is within the allowable [minRadiusKm] and [maxRadiusKm] bounds.
  static bool isValid(double? radiusKm) {
    if (radiusKm == null) return false;
    return radiusKm >= minRadiusKm && radiusKm <= maxRadiusKm;
  }

  /// Formatted range helper for UI labels (e.g. '10–20 km').
  static String get rangeHelpText => '${minRadiusKm.toInt()}–${maxRadiusKm.toInt()} km';
}

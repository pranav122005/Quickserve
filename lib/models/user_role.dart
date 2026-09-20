import '../core/errors/app_exception.dart';

/// Supported system user roles in QuickServe.
enum UserRole {
  customer('customer', 'Customer'),
  agent('agent', 'Agent'),
  admin('admin', 'Admin');

  final String dbValue;
  final String displayName;

  const UserRole(this.dbValue, this.displayName);

  bool get isCustomer => this == UserRole.customer;
  bool get isAgent => this == UserRole.agent;
  bool get isAdmin => this == UserRole.admin;

  /// Parses a raw database string into a [UserRole].
  /// Throws [InvalidRoleException] if the role is unrecognized or null.
  static UserRole fromString(String? role) {
    if (role == null) {
      throw const InvalidRoleException(null, 'User role is null.');
    }
    final normalized = role.trim().toLowerCase();
    for (final r in UserRole.values) {
      if (r.dbValue == normalized) {
        return r;
      }
    }
    throw InvalidRoleException(role, 'Unrecognized user role: "$role".');
  }

  /// Safely attempts to parse a role string, returning null if invalid.
  static UserRole? tryParse(String? role) {
    if (role == null) return null;
    final normalized = role.trim().toLowerCase();
    for (final r in UserRole.values) {
      if (r.dbValue == normalized) {
        return r;
      }
    }
    return null;
  }
}

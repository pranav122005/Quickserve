import 'user_role.dart';
import '../core/constants/app_constants.dart';

/// Represents a user profile stored in the public.profiles database table.
class UserProfile {
  final String id;
  final String fullName;
  final String? phone;
  final UserRole role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    this.phone,
    required this.role,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map[DbColumns.id] as String,
      fullName: (map[DbColumns.fullName] as String?) ?? '',
      phone: map[DbColumns.phone] as String?,
      role: UserRole.fromString(map[DbColumns.role] as String?),
      createdAt: map[DbColumns.createdAt] != null
          ? DateTime.tryParse(map[DbColumns.createdAt] as String)
          : null,
      updatedAt: map[DbColumns.updatedAt] != null
          ? DateTime.tryParse(map[DbColumns.updatedAt] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DbColumns.id: id,
      DbColumns.fullName: fullName,
      DbColumns.phone: phone,
      DbColumns.role: role.dbValue,
      if (createdAt != null) DbColumns.createdAt: createdAt!.toIso8601String(),
      if (updatedAt != null) DbColumns.updatedAt: updatedAt!.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? phone,
    UserRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          fullName == other.fullName &&
          phone == other.phone &&
          role == other.role;

  @override
  int get hashCode =>
      id.hashCode ^ fullName.hashCode ^ (phone?.hashCode ?? 0) ^ role.hashCode;

  @override
  String toString() =>
      'UserProfile(id: $id, fullName: $fullName, role: ${role.dbValue})';
}

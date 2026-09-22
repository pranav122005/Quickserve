import '../core/constants/app_constants.dart';
import 'user_profile.dart';

/// Agent availability states in the database schema (`offline`, `available`).
enum AgentAvailability {
  offline('offline', 'Offline'),
  available('available', 'Available');

  final String dbValue;
  final String displayName;

  const AgentAvailability(this.dbValue, this.displayName);

  bool get isAvailable => this == AgentAvailability.available;
  bool get isOffline => this == AgentAvailability.offline;

  static AgentAvailability fromString(String? value) {
    if (value == null) return AgentAvailability.offline;
    final normalized = value.trim().toLowerCase();
    for (final a in AgentAvailability.values) {
      if (a.dbValue == normalized) return a;
    }
    return AgentAvailability.offline;
  }
}

/// Represents a record in the `public.agent_profiles` table.
class AgentProfile {
  final String userId;
  final double serviceRadiusKm;
  final AgentAvailability availability;
  final bool isVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final UserProfile? userProfile;

  const AgentProfile({
    required this.userId,
    this.serviceRadiusKm = 15.0,
    this.availability = AgentAvailability.offline,
    this.isVerified = false,
    this.createdAt,
    this.updatedAt,
    this.userProfile,
  });

  factory AgentProfile.fromMap(Map<String, dynamic> map) {
    UserProfile? joinedProfile;
    if (map['profiles'] is Map<String, dynamic>) {
      joinedProfile = UserProfile.fromMap(map['profiles'] as Map<String, dynamic>);
    }

    return AgentProfile(
      userId: map[DbColumns.userId] as String,
      serviceRadiusKm: (map[DbColumns.serviceRadiusKm] as num?)?.toDouble() ?? 15.0,
      availability: AgentAvailability.fromString(map[DbColumns.availability] as String?),
      isVerified: (map[DbColumns.isVerified] as bool?) ?? false,
      createdAt: map[DbColumns.createdAt] != null
          ? DateTime.tryParse(map[DbColumns.createdAt] as String)
          : null,
      updatedAt: map[DbColumns.updatedAt] != null
          ? DateTime.tryParse(map[DbColumns.updatedAt] as String)
          : null,
      userProfile: joinedProfile,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DbColumns.userId: userId,
      DbColumns.serviceRadiusKm: serviceRadiusKm,
      DbColumns.availability: availability.dbValue,
      DbColumns.isVerified: isVerified,
    };
  }

  AgentProfile copyWith({
    String? userId,
    double? serviceRadiusKm,
    AgentAvailability? availability,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserProfile? userProfile,
  }) {
    return AgentProfile(
      userId: userId ?? this.userId,
      serviceRadiusKm: serviceRadiusKm ?? this.serviceRadiusKm,
      availability: availability ?? this.availability,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userProfile: userProfile ?? this.userProfile,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentProfile &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          availability == other.availability &&
          serviceRadiusKm == other.serviceRadiusKm;

  @override
  int get hashCode => userId.hashCode ^ availability.hashCode ^ serviceRadiusKm.hashCode;
}

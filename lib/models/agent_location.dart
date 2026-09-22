import '../core/constants/app_constants.dart';
import '../core/utils/geo_utils.dart';

/// Represents a current geographic location record in `public.agent_locations`.
class AgentLocation {
  final String agentId;
  final GeoPoint location;
  final DateTime? updatedAt;

  const AgentLocation({
    required this.agentId,
    required this.location,
    this.updatedAt,
  });

  /// Returns true if the location has not been updated within [thresholdSeconds] (default 120s).
  bool isStale({int thresholdSeconds = 120, DateTime? referenceTime}) {
    if (updatedAt == null) return true;
    final now = referenceTime ?? DateTime.now();
    return now.difference(updatedAt!).inSeconds > thresholdSeconds;
  }

  factory AgentLocation.fromMap(Map<String, dynamic> map) {
    final rawLoc = map['location'];
    final parsedPoint = GeoUtils.parsePoint(rawLoc) ??
        const GeoPoint(latitude: 0.0, longitude: 0.0);

    return AgentLocation(
      agentId: (map['agent_id'] as String?) ?? '',
      location: parsedPoint,
      updatedAt: map[DbColumns.updatedAt] != null
          ? DateTime.tryParse(map[DbColumns.updatedAt] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'agent_id': agentId,
      'location': location.toWkt(),
      DbColumns.updatedAt: (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  AgentLocation copyWith({
    String? agentId,
    GeoPoint? location,
    DateTime? updatedAt,
  }) {
    return AgentLocation(
      agentId: agentId ?? this.agentId,
      location: location ?? this.location,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentLocation &&
          runtimeType == other.runtimeType &&
          agentId == other.agentId &&
          location == other.location;

  @override
  int get hashCode => agentId.hashCode ^ location.hashCode;

  @override
  String toString() =>
      'AgentLocation(agentId: $agentId, lat: ${location.latitude}, lon: ${location.longitude}, updatedAt: $updatedAt)';
}

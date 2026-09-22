import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../services/geolocation_service.dart';

class AgentLocationState {
  final bool isPublishing;
  final double? latitude;
  final double longitude;
  final DateTime? lastPublishedAt;
  final String? errorMessage;

  const AgentLocationState({
    this.isPublishing = false,
    this.latitude,
    this.longitude = 0.0,
    this.lastPublishedAt,
    this.errorMessage,
  });

  AgentLocationState copyWith({
    bool? isPublishing,
    double? latitude,
    double? longitude,
    DateTime? lastPublishedAt,
    String? errorMessage,
  }) {
    return AgentLocationState(
      isPublishing: isPublishing ?? this.isPublishing,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastPublishedAt: lastPublishedAt ?? this.lastPublishedAt,
      errorMessage: errorMessage,
    );
  }
}

class AgentLocationController extends Notifier<AgentLocationState> {
  StreamSubscription<GeoPosition>? _positionSub;

  @override
  AgentLocationState build() {
    ref.onDispose(() {
      _positionSub?.cancel();
    });
    return const AgentLocationState();
  }

  /// Starts throttled periodic location publishing to Supabase `agent_locations`.
  Future<bool> startPublishing(String agentId) async {
    if (state.isPublishing) return true;

    final geoService = ref.read(geolocationServiceProvider);
    final repo = ref.read(agentLocationRepositoryProvider);

    final perm = await geoService.checkPermission();
    if (perm != LocationPermissionStatus.granted) {
      state = state.copyWith(
        isPublishing: false,
        errorMessage: perm == LocationPermissionStatus.serviceDisabled
            ? 'GPS is disabled on this device. Please turn on Location.'
            : 'Location permission is required to share GPS with the customer.',
      );
      return false;
    }

    state = state.copyWith(isPublishing: true, errorMessage: null);

    _positionSub = geoService
        .watchPosition(interval: const Duration(seconds: 10), distanceFilterMeters: 20)
        .listen(
      (pos) async {
        try {
          await repo.updateCurrentLocation(
            agentId: agentId,
            latitude: pos.latitude,
            longitude: pos.longitude,
          );

          state = state.copyWith(
            latitude: pos.latitude,
            longitude: pos.longitude,
            lastPublishedAt: pos.timestamp,
            errorMessage: null,
          );
        } catch (e) {
          state = state.copyWith(errorMessage: 'Location update error: $e');
        }
      },
      onError: (err) {
        state = state.copyWith(
          isPublishing: false,
          errorMessage: 'Geolocation error: $err',
        );
      },
    );
    return true;
  }

  /// Starts location publishing ONLY when backend state confirms:
  /// assignment.status == 'accepted' AND request.status IN ('assigned', 'in_progress').
  Future<bool> startPublishingIfAuthorized({
    required String agentId,
    required String requestId,
  }) async {
    try {
      final assignRepo = ref.read(assignmentRepositoryProvider);
      final reqRepo = ref.read(serviceRequestRepositoryProvider);

      final assignment = await assignRepo.getAssignmentForRequest(requestId);
      final request = await reqRepo.getRequestById(requestId);

      if (assignment == null ||
          assignment.agentId != agentId ||
          !assignment.status.isAccepted ||
          (!request.status.isAssigned && !request.status.isInProgress)) {
        stopPublishing();
        state = state.copyWith(
          errorMessage: 'GPS publishing not authorized for this request state.',
        );
        return false;
      }

      return await startPublishing(agentId);
    } catch (e) {
      stopPublishing();
      state = state.copyWith(errorMessage: 'Verification failed: $e');
      return false;
    }
  }

  /// Stops background location publishing.
  void stopPublishing() {
    _positionSub?.cancel();
    _positionSub = null;
    state = state.copyWith(isPublishing: false);
  }

  /// Manually transmits a location update (useful for testing & simulator controls).
  Future<void> updateLocationManually({
    required String agentId,
    required double latitude,
    required double longitude,
  }) async {
    if (!GeoUtils.isValidCoordinates(latitude, longitude)) {
      state = state.copyWith(
        errorMessage: 'Invalid coordinates: latitude must be [-90, 90], longitude [-180, 180].',
      );
      return;
    }

    try {
      final repo = ref.read(agentLocationRepositoryProvider);
      await repo.updateCurrentLocation(
        agentId: agentId,
        latitude: latitude,
        longitude: longitude,
      );

      state = state.copyWith(
        latitude: latitude,
        longitude: longitude,
        lastPublishedAt: DateTime.now(),
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Manual update failed: $e');
    }
  }
}

final agentLocationControllerProvider =
    NotifierProvider<AgentLocationController, AgentLocationState>(
  AgentLocationController.new,
);

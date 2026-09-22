import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import 'auth_repository.dart';
import 'auth_repository_impl.dart';
import 'profile_repository.dart';
import 'profile_repository_impl.dart';
import 'service_request_repository.dart';
import 'service_request_repository_impl.dart';
import 'assignment_repository.dart';
import 'assignment_repository_impl.dart';
import 'agent_profile_repository.dart';
import 'agent_profile_repository_impl.dart';
import 'payment_repository.dart';
import 'payment_repository_impl.dart';
import 'status_history_repository.dart';
import 'status_history_repository_impl.dart';
import 'agent_location_repository.dart';
import 'agent_location_repository_impl.dart';
import '../services/dispatch_service.dart';
import '../services/realtime_service.dart';
import '../services/geolocation_service.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AuthRepositoryImpl(supabaseService);
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return ProfileRepositoryImpl(supabaseService);
});

final serviceRequestRepositoryProvider = Provider<ServiceRequestRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return ServiceRequestRepositoryImpl(supabaseService);
});

final assignmentRepositoryProvider = Provider<AssignmentRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AssignmentRepositoryImpl(supabaseService);
});

final agentProfileRepositoryProvider = Provider<AgentProfileRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AgentProfileRepositoryImpl(supabaseService);
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return PaymentRepositoryImpl(supabaseService);
});

final statusHistoryRepositoryProvider = Provider<StatusHistoryRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return StatusHistoryRepositoryImpl(supabaseService);
});

final dispatchServiceProvider = Provider<DispatchService>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return DispatchService(supabaseService);
});

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return RealtimeService(supabaseService);
});

final agentLocationRepositoryProvider = Provider<AgentLocationRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return AgentLocationRepositoryImpl(supabaseService);
});

final geolocationServiceProvider = Provider<GeolocationService>((ref) {
  return GeolocationServiceImpl();
});

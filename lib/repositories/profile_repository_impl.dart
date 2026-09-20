import 'profile_repository.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';

/// Implementation of [ProfileRepository] querying the public.profiles table.
class ProfileRepositoryImpl implements ProfileRepository {
  final SupabaseService _supabaseService;

  ProfileRepositoryImpl(this._supabaseService);

  @override
  Future<UserProfile> getProfile(String userId) async {
    final response = await _supabaseService.client
        .from(DbTables.profiles)
        .select()
        .eq(DbColumns.id, userId)
        .maybeSingle();

    if (response == null) {
      throw ProfileNotFoundException(
        'User profile record not found in the database.',
        'User ID: $userId',
      );
    }

    return UserProfile.fromMap(response);
  }

  @override
  Future<UserProfile?> getProfileOrNull(String userId) async {
    final response = await _supabaseService.client
        .from(DbTables.profiles)
        .select()
        .eq(DbColumns.id, userId)
        .maybeSingle();

    if (response == null) return null;
    return UserProfile.fromMap(response);
  }
}

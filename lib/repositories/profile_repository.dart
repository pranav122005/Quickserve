import '../models/user_profile.dart';

/// Contract for accessing user profile records from the database.
abstract class ProfileRepository {
  /// Retrieves the profile for [userId].
  /// Throws [ProfileNotFoundException] if the record does not exist.
  Future<UserProfile> getProfile(String userId);

  /// Retrieves the profile for [userId], or returns null if not found.
  Future<UserProfile?> getProfileOrNull(String userId);

  /// Retrieves all customer profiles (admin view).
  Future<List<UserProfile>> getAllCustomers();
}

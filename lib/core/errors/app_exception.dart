/// Base class for all application-level exceptions.
abstract class AppException implements Exception {
  final String message;
  final String? technicalDetails;

  const AppException(this.message, {this.technicalDetails});

  @override
  String toString() => message;
}

/// Authentication-related exceptions (invalid credentials, email taken, etc.)
class AuthFailureException extends AppException {
  const AuthFailureException(super.message, {super.technicalDetails});
}

/// Thrown when an authenticated user's profile does not exist in public.profiles.
class ProfileNotFoundException extends AppException {
  const ProfileNotFoundException([
    super.message = 'User profile was not found. Please contact support.',
    String? technicalDetails,
  ]) : super(technicalDetails: technicalDetails);
}

/// Thrown when a user has a role that is not recognized by the system.
class InvalidRoleException extends AppException {
  final String? rawRole;
  const InvalidRoleException([
    this.rawRole,
    super.message = 'The assigned user role is invalid or unrecognized.',
  ]);
}

/// Thrown when a user attempts to access an unauthorized route or action.
class UnauthorizedRoleException extends AppException {
  const UnauthorizedRoleException([
    super.message = 'You do not have permission to access this area.',
  ]);
}

/// Thrown when required environment variables are missing or misconfigured.
class ConfigurationException extends AppException {
  const ConfigurationException(super.message, {super.technicalDetails});
}

/// Thrown when network connectivity fails.
class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Network connection failed. Please check your internet connection.',
  ]);
}

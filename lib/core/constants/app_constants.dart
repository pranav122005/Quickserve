/// Application-wide constants for routing, database tables, and roles.
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
}

class DbColumns {
  static const String id = 'id';
  static const String fullName = 'full_name';
  static const String phone = 'phone';
  static const String role = 'role';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}

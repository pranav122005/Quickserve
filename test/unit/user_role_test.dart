import 'package:flutter_test/flutter_test.dart';
import 'package:quickserve/core/errors/app_exception.dart';
import 'package:quickserve/models/user_role.dart';

void main() {
  group('UserRole Tests', () {
    test('parses valid role strings accurately', () {
      expect(UserRole.fromString('customer'), UserRole.customer);
      expect(UserRole.fromString('agent'), UserRole.agent);
      expect(UserRole.fromString('admin'), UserRole.admin);
    });

    test('parses role strings case-insensitively with whitespace', () {
      expect(UserRole.fromString(' Customer '), UserRole.customer);
      expect(UserRole.fromString('AGENT'), UserRole.agent);
      expect(UserRole.fromString(' Admin '), UserRole.admin);
    });

    test('throws InvalidRoleException when role string is null or invalid', () {
      expect(
        () => UserRole.fromString(null),
        throwsA(isA<InvalidRoleException>()),
      );
      expect(
        () => UserRole.fromString('superadmin'),
        throwsA(isA<InvalidRoleException>()),
      );
      expect(
        () => UserRole.fromString(''),
        throwsA(isA<InvalidRoleException>()),
      );
    });

    test('tryParse returns null on invalid or null input without throwing', () {
      expect(UserRole.tryParse(null), isNull);
      expect(UserRole.tryParse('unknown'), isNull);
      expect(UserRole.tryParse('customer'), UserRole.customer);
    });

    test('role boolean helper flags work as expected', () {
      const customer = UserRole.customer;
      expect(customer.isCustomer, isTrue);
      expect(customer.isAgent, isFalse);
      expect(customer.isAdmin, isFalse);

      const agent = UserRole.agent;
      expect(agent.isCustomer, isFalse);
      expect(agent.isAgent, isTrue);
      expect(agent.isAdmin, isFalse);

      const admin = UserRole.admin;
      expect(admin.isCustomer, isFalse);
      expect(admin.isAgent, isFalse);
      expect(admin.isAdmin, isTrue);
    });
  });
}

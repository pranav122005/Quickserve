import 'package:flutter_test/flutter_test.dart';
import 'package:quickserve/services/audit_service.dart';

void main() {
  group('AuditService Unit Tests', () {
    late AuditService auditService;

    setUp(() {
      auditService = AuditService();
    });

    test('All 6 mandated event types are defined and accessible', () {
      expect(AuditEventType.all, containsAll([
        'LOGIN_SUCCESS',
        'REQUEST_CREATED',
        'REQUEST_ASSIGNED',
        'REQUEST_UPDATED',
        'AUTHORIZATION_FAILED',
        'DATABASE_ERROR',
      ]));
    });

    test('Audit logging records events and exposes them via events list', () {
      final initialCount = auditService.events.length;

      auditService.logLoginSuccess('user-123', email: 'admin@quickserve.com', role: 'admin');
      auditService.logRequestCreated('req-001', 'cust-789', category: 'Cleaning', title: 'Deep clean');
      auditService.logRequestAssigned('req-001', 'agent-456', mechanism: 'postgis');
      auditService.logRequestUpdated('req-001', 'in_progress', note: 'Technician on site');
      auditService.logAuthorizationFailed(path: '/admin', role: 'customer', reason: 'Role required: admin');
      auditService.logDatabaseError('select_requests', 'Connection reset');

      expect(auditService.events.length, initialCount + 6);

      expect(auditService.events[0].eventType, AuditEventType.databaseError);
      expect(auditService.events[1].eventType, AuditEventType.authorizationFailed);
      expect(auditService.events[2].eventType, AuditEventType.requestUpdated);
      expect(auditService.events[3].eventType, AuditEventType.requestAssigned);
      expect(auditService.events[4].eventType, AuditEventType.requestCreated);
      expect(auditService.events[5].eventType, AuditEventType.loginSuccess);
    });

    test('Sensitive keys are recursively masked to protect secrets in logs', () {
      auditService.log(
        eventType: AuditEventType.loginSuccess,
        actorId: 'test-user',
        details: 'Login check',
        metadata: {
          'user': 'pranav@quickserve.com',
          'password': 'SuperSecretPassword123!',
          'authToken': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9',
          'apiKey': 'anon-key-value',
          'nested': {
            'secret_key': 'top-secret',
            'public_info': 'safe-to-log',
          },
        },
      );

      final logged = auditService.events.first;
      expect(logged.metadata['user'], 'pranav@quickserve.com');
      expect(logged.metadata['password'], '***MASKED***');
      expect(logged.metadata['authToken'], '***MASKED***');
      expect(logged.metadata['apiKey'], '***MASKED***');

      final nested = logged.metadata['nested'] as Map<String, dynamic>;
      expect(nested['secret_key'], '***MASKED***');
      expect(nested['public_info'], 'safe-to-log');
    });
  });
}

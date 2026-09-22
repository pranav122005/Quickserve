import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Exact audit event types mandated by the technical specification.
class AuditEventType {
  static const String loginSuccess = 'LOGIN_SUCCESS';
  static const String requestCreated = 'REQUEST_CREATED';
  static const String requestAssigned = 'REQUEST_ASSIGNED';
  static const String requestUpdated = 'REQUEST_UPDATED';
  static const String authorizationFailed = 'AUTHORIZATION_FAILED';
  static const String databaseError = 'DATABASE_ERROR';

  static const List<String> all = [
    loginSuccess,
    requestCreated,
    requestAssigned,
    requestUpdated,
    authorizationFailed,
    databaseError,
  ];
}

/// Represents a single recorded audit log entry.
class AuditEvent {
  final String id;
  final String eventType;
  final String actorId;
  final String details;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  AuditEvent({
    required this.id,
    required this.eventType,
    required this.actorId,
    required this.details,
    required this.metadata,
    required this.timestamp,
  });
}

/// Centralized audit logging service.
/// Enforces secret sanitization: never logs passwords, tokens, or API keys.
class AuditService {
  static final AuditService _instance = AuditService._internal();
  factory AuditService() => _instance;
  AuditService._internal();

  final List<AuditEvent> _events = [];
  static const int _maxEvents = 250;

  List<AuditEvent> get events => List.unmodifiable(_events);

  /// Sensitive key patterns that must be sanitized from audit metadata.
  static final RegExp _sensitivePattern = RegExp(
    r'(password|token|secret|key|authorization|bearer|auth|apikey|anonkey)',
    caseSensitive: false,
  );

  /// Logs a structured audit event.
  AuditEvent log({
    required String eventType,
    String? actorId,
    required String details,
    Map<String, dynamic>? metadata,
  }) {
    final sanitizedMeta = _sanitizeMetadata(metadata);
    final event = AuditEvent(
      id: 'aud-${DateTime.now().millisecondsSinceEpoch}-${_events.length + 1}',
      eventType: eventType,
      actorId: actorId ?? 'system',
      details: details,
      metadata: sanitizedMeta,
      timestamp: DateTime.now(),
    );

    _events.insert(0, event);
    if (_events.length > _maxEvents) {
      _events.removeLast();
    }

    // Developer logging without leaking sensitive payloads
    dev.log(
      '[$eventType] ${event.details} (actor: ${event.actorId})',
      name: 'QuickServe.Audit',
    );

    return event;
  }

  // --- Specialized Helper Loggers ---

  void logLoginSuccess(String userId, {String? email, String? role}) {
    log(
      eventType: AuditEventType.loginSuccess,
      actorId: userId,
      details: 'User authenticated successfully ($email, role: $role)',
      metadata: {'userId': userId, 'email': email, 'role': role},
    );
  }

  void logRequestCreated(
    String requestId,
    String customerId, {
    String? category,
    String? title,
  }) {
    log(
      eventType: AuditEventType.requestCreated,
      actorId: customerId,
      details: 'Service request created: $requestId ($category)',
      metadata: {
        'requestId': requestId,
        'customerId': customerId,
        'category': category,
        'title': title,
      },
    );
  }

  void logRequestAssigned(
    String requestId,
    String agentId, {
    String? assignmentId,
    String? mechanism,
  }) {
    log(
      eventType: AuditEventType.requestAssigned,
      actorId: agentId,
      details: 'Request $requestId assigned to agent $agentId via ${mechanism ?? "dispatch"}',
      metadata: {
        'requestId': requestId,
        'agentId': agentId,
        'assignmentId': assignmentId,
        'mechanism': mechanism ?? 'dispatch',
      },
    );
  }

  void logRequestUpdated(
    String requestId,
    String newStatus, {
    String? actorId,
    String? note,
  }) {
    final meta = <String, dynamic>{
      'requestId': requestId,
      'newStatus': newStatus,
    };
    if (note != null) {
      meta['note'] = note;
    }
    log(
      eventType: AuditEventType.requestUpdated,
      actorId: actorId,
      details: 'Request $requestId transitioned to status $newStatus${note != null ? " ($note)" : ""}',
      metadata: meta,
    );
  }

  void logAuthorizationFailed({
    String? path,
    String? role,
    String? reason,
    String? actorId,
  }) {
    log(
      eventType: AuditEventType.authorizationFailed,
      actorId: actorId ?? 'unauthenticated',
      details: 'Authorization denied: path=$path, role=$role, reason=$reason',
      metadata: {'path': path, 'role': role, 'reason': reason},
    );
  }

  void logDatabaseError(
    String operation,
    dynamic error, {
    String? context,
    String? actorId,
  }) {
    log(
      eventType: AuditEventType.databaseError,
      actorId: actorId,
      details: 'Database operation failed during $operation: ${error.toString()}',
      metadata: {'operation': operation, 'context': context},
    );
  }

  /// Recursively sanitizes maps, masking any values whose keys contain sensitive keywords.
  Map<String, dynamic> _sanitizeMetadata(Map<String, dynamic>? raw) {
    if (raw == null) return {};
    final sanitized = <String, dynamic>{};
    for (final entry in raw.entries) {
      if (_sensitivePattern.hasMatch(entry.key)) {
        sanitized[entry.key] = '***MASKED***';
      } else if (entry.value is Map<String, dynamic>) {
        sanitized[entry.key] = _sanitizeMetadata(entry.value as Map<String, dynamic>);
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }
}

/// Riverpod provider for the AuditService instance.
final auditServiceProvider = Provider<AuditService>((ref) {
  return AuditService();
});

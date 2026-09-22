import '../core/constants/app_constants.dart';

/// Payment methods supported in Phase 2 recording.
enum PaymentMethod {
  cash('cash', 'Cash'),
  upi('upi', 'UPI'),
  other('other', 'Other');

  final String dbValue;
  final String displayName;

  const PaymentMethod(this.dbValue, this.displayName);

  static PaymentMethod fromString(String? value) {
    if (value == null) return PaymentMethod.cash;
    final normalized = value.trim().toLowerCase();
    for (final m in PaymentMethod.values) {
      if (m.dbValue == normalized) return m;
    }
    return PaymentMethod.other;
  }
}

/// Payment transaction statuses in the database schema.
enum PaymentStatus {
  pending('pending', 'Pending'),
  paid('paid', 'Paid'),
  failed('failed', 'Failed');

  final String dbValue;
  final String displayName;

  const PaymentStatus(this.dbValue, this.displayName);

  bool get isPaid => this == PaymentStatus.paid;
  bool get isPending => this == PaymentStatus.pending;
  bool get isFailed => this == PaymentStatus.failed;

  static PaymentStatus fromString(String? value) {
    if (value == null) return PaymentStatus.pending;
    final normalized = value.trim().toLowerCase();
    for (final s in PaymentStatus.values) {
      if (s.dbValue == normalized) return s;
    }
    return PaymentStatus.pending;
  }
}

/// Represents a record in the `public.payments` table.
class PaymentRecord {
  final String id;
  final String requestId;
  final String customerId;
  final String agentId;
  final double amount;
  final String currency;
  final PaymentMethod method;
  final PaymentStatus status;
  final DateTime? paidAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PaymentRecord({
    required this.id,
    required this.requestId,
    required this.customerId,
    required this.agentId,
    required this.amount,
    this.currency = 'INR',
    required this.method,
    required this.status,
    this.paidAt,
    this.createdAt,
    this.updatedAt,
  });

  factory PaymentRecord.fromMap(Map<String, dynamic> map) {
    return PaymentRecord(
      id: map[DbColumns.id] as String,
      requestId: map[DbColumns.requestId] as String,
      customerId: map[DbColumns.customerId] as String,
      agentId: map[DbColumns.agentId] as String,
      amount: (map[DbColumns.amount] as num?)?.toDouble() ?? 0.0,
      currency: (map[DbColumns.currency] as String?) ?? 'INR',
      method: PaymentMethod.fromString(map[DbColumns.method] as String?),
      status: PaymentStatus.fromString(map[DbColumns.status] as String?),
      paidAt: map[DbColumns.paidAt] != null
          ? DateTime.tryParse(map[DbColumns.paidAt] as String)
          : null,
      createdAt: map[DbColumns.createdAt] != null
          ? DateTime.tryParse(map[DbColumns.createdAt] as String)
          : null,
      updatedAt: map[DbColumns.updatedAt] != null
          ? DateTime.tryParse(map[DbColumns.updatedAt] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      DbColumns.requestId: requestId,
      DbColumns.customerId: customerId,
      DbColumns.agentId: agentId,
      DbColumns.amount: amount,
      DbColumns.currency: currency,
      DbColumns.method: method.dbValue,
      DbColumns.status: status.dbValue,
      if (paidAt != null) DbColumns.paidAt: paidAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => toInsertMap();

  PaymentRecord copyWith({
    String? id,
    String? requestId,
    String? customerId,
    String? agentId,
    double? amount,
    String? currency,
    PaymentMethod? method,
    PaymentStatus? status,
    DateTime? paidAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentRecord(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      customerId: customerId ?? this.customerId,
      agentId: agentId ?? this.agentId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      method: method ?? this.method,
      status: status ?? this.status,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          amount == other.amount &&
          status == other.status;

  @override
  int get hashCode => id.hashCode ^ amount.hashCode ^ status.hashCode;
}

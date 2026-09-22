import 'package:flutter_test/flutter_test.dart';
import 'package:quickserve/models/payment_record.dart';
import 'package:quickserve/core/constants/app_constants.dart';

void main() {
  group('PaymentRecord Model Tests', () {
    test('PaymentMethod enum parses allowed methods correctly', () {
      expect(PaymentMethod.fromString('cash'), PaymentMethod.cash);
      expect(PaymentMethod.fromString('upi'), PaymentMethod.upi);
      expect(PaymentMethod.fromString('other'), PaymentMethod.other);

      // Fallback for null or unknown
      expect(PaymentMethod.fromString(null), PaymentMethod.cash);
      expect(PaymentMethod.fromString('credit_card'), PaymentMethod.other);
    });

    test('PaymentStatus enum parses allowed statuses and evaluates flags', () {
      expect(PaymentStatus.fromString('pending'), PaymentStatus.pending);
      expect(PaymentStatus.fromString('paid'), PaymentStatus.paid);
      expect(PaymentStatus.fromString('failed'), PaymentStatus.failed);

      expect(PaymentStatus.paid.isPaid, isTrue);
      expect(PaymentStatus.pending.isPending, isTrue);
      expect(PaymentStatus.failed.isFailed, isTrue);
    });

    test('PaymentRecord deserializes from Map correctly', () {
      final map = {
        DbColumns.id: 'pay-uuid-1',
        DbColumns.requestId: 'req-uuid-1',
        DbColumns.customerId: 'cust-uuid-1',
        DbColumns.agentId: 'agent-uuid-1',
        DbColumns.amount: 850.50,
        DbColumns.currency: 'INR',
        DbColumns.method: 'upi',
        DbColumns.status: 'paid',
        DbColumns.paidAt: '2026-09-20T12:00:00.000Z',
        DbColumns.createdAt: '2026-09-20T12:00:00.000Z',
        DbColumns.updatedAt: '2026-09-20T12:00:00.000Z',
      };

      final payment = PaymentRecord.fromMap(map);

      expect(payment.id, 'pay-uuid-1');
      expect(payment.requestId, 'req-uuid-1');
      expect(payment.customerId, 'cust-uuid-1');
      expect(payment.agentId, 'agent-uuid-1');
      expect(payment.amount, 850.50);
      expect(payment.currency, 'INR');
      expect(payment.method, PaymentMethod.upi);
      expect(payment.status, PaymentStatus.paid);
      expect(payment.paidAt, isNotNull);
    });

    test('PaymentRecord serializes to Map correctly', () {
      final payment = PaymentRecord(
        id: 'pay-uuid-2',
        requestId: 'req-uuid-2',
        customerId: 'cust-uuid-2',
        agentId: 'agent-uuid-2',
        amount: 1200.0,
        currency: 'INR',
        method: PaymentMethod.cash,
        status: PaymentStatus.paid,
      );

      final map = payment.toMap();

      expect(map[DbColumns.requestId], 'req-uuid-2');
      expect(map[DbColumns.amount], 1200.0);
      expect(map[DbColumns.method], 'cash');
      expect(map[DbColumns.status], 'paid');
    });
  });
}

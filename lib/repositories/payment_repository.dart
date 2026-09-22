import '../models/payment_record.dart';

abstract class PaymentRepository {
  Future<PaymentRecord> recordPayment({
    required String requestId,
    required String customerId,
    required String agentId,
    required double amount,
    String currency = 'INR',
    required PaymentMethod method,
    PaymentStatus status = PaymentStatus.paid,
  });

  Future<PaymentRecord?> getPaymentForRequest(String requestId);
  Future<List<PaymentRecord>> getAllPayments();
  Future<List<PaymentRecord>> getCustomerPayments(String customerId);
}

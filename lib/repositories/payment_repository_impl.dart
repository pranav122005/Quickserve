import 'payment_repository.dart';
import '../models/payment_record.dart';
import '../services/supabase_service.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final SupabaseService _supabaseService;

  PaymentRepositoryImpl(this._supabaseService);

  @override
  Future<PaymentRecord> recordPayment({
    required String requestId,
    required String customerId,
    required String agentId,
    required double amount,
    String currency = 'INR',
    required PaymentMethod method,
    PaymentStatus status = PaymentStatus.paid,
  }) async {
    if (amount <= 0) {
      throw const ValidationException('Payment amount must be greater than zero.');
    }

    final nowIso = DateTime.now().toIso8601String();

    final response = await _supabaseService.client
        .from(DbTables.payments)
        .insert({
          DbColumns.requestId: requestId,
          DbColumns.customerId: customerId,
          DbColumns.agentId: agentId,
          DbColumns.amount: amount,
          DbColumns.currency: currency,
          DbColumns.method: method.dbValue,
          DbColumns.status: status.dbValue,
          DbColumns.paidAt: status.isPaid ? nowIso : null,
        })
        .select()
        .single();

    return PaymentRecord.fromMap(response);
  }

  @override
  Future<PaymentRecord?> getPaymentForRequest(String requestId) async {
    final response = await _supabaseService.client
        .from(DbTables.payments)
        .select()
        .eq(DbColumns.requestId, requestId)
        .maybeSingle();

    if (response == null) return null;
    return PaymentRecord.fromMap(response);
  }

  @override
  Future<List<PaymentRecord>> getAllPayments() async {
    final response = await _supabaseService.client
        .from(DbTables.payments)
        .select()
        .order(DbColumns.createdAt, ascending: false);

    final list = response as List;
    return list.map((item) => PaymentRecord.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<PaymentRecord>> getCustomerPayments(String customerId) async {
    final response = await _supabaseService.client
        .from(DbTables.payments)
        .select()
        .eq(DbColumns.customerId, customerId)
        .order(DbColumns.createdAt, ascending: false);

    final list = response as List;
    return list.map((item) => PaymentRecord.fromMap(item as Map<String, dynamic>)).toList();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/payment_record.dart';
import '../../../../models/service_assignment.dart';
import '../controllers/agent_controller.dart';

class RecordPaymentDialog extends ConsumerStatefulWidget {
  final ServiceAssignment assignment;

  const RecordPaymentDialog({super.key, required this.assignment});

  @override
  ConsumerState<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  PaymentStatus _selectedStatus = PaymentStatus.paid;
  String _currency = 'INR';
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid positive amount.');
      return;
    }

    final req = widget.assignment.request;
    if (req == null) {
      setState(() => _error = 'Associated service request details are missing.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final success = await ref.read(agentDashboardProvider.notifier).recordPayment(
          requestId: req.id,
          customerId: req.customerId,
          amount: amount,
          currency: _currency,
          method: _selectedMethod,
          status: _selectedStatus,
        );

    if (mounted) {
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment record saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _isSubmitting = false;
          _error = ref.read(agentDashboardProvider).errorMessage ??
              'Failed to record payment. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.assignment.request;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.payment, color: Colors.green.shade800),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Record Service Payment',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (req != null) ...[
                  Text(
                    'Request: ${req.title}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Address: ${req.serviceAddress}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                    ),
                  ),
                // Amount & Currency Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          hintText: 'e.g. 500.00',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter amount.';
                          }
                          final num = double.tryParse(val.trim());
                          if (num == null || num <= 0) {
                            return 'Enter a positive number.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _currency,
                        decoration: const InputDecoration(labelText: 'Currency'),
                        items: ['INR', 'USD', 'EUR']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _currency = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Payment Method
                DropdownButtonFormField<PaymentMethod>(
                  initialValue: _selectedMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: PaymentMethod.values
                      .map((m) => DropdownMenuItem(value: m, child: Text(m.displayName)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMethod = val);
                  },
                ),
                const SizedBox(height: 16),
                // Payment Status
                DropdownButtonFormField<PaymentStatus>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Payment Status',
                    prefixIcon: Icon(Icons.check_circle_outline),
                  ),
                  items: [PaymentStatus.paid, PaymentStatus.pending]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.displayName)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatus = val);
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Payment Record'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

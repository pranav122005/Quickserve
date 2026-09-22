import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/priority_badge.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../models/service_assignment.dart';
import '../controllers/agent_controller.dart';

class IncomingOfferCard extends ConsumerStatefulWidget {
  final ServiceAssignment offer;

  const IncomingOfferCard({super.key, required this.offer});

  @override
  ConsumerState<IncomingOfferCard> createState() => _IncomingOfferCardState();
}

class _IncomingOfferCardState extends ConsumerState<IncomingOfferCard> {
  Timer? _timer;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.offer.remainingOfferSeconds();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final rem = widget.offer.remainingOfferSeconds();
      if (mounted) {
        setState(() {
          _remainingSeconds = rem;
        });
      }
      if (rem <= 0) {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final req = offer.request;
    final isExpired = _remainingSeconds <= 0;
    final progress = (_remainingSeconds / 120.0).clamp(0.0, 1.0);

    Color timerColor = Colors.green.shade700;
    if (_remainingSeconds <= 30) {
      timerColor = Colors.red.shade700;
    } else if (_remainingSeconds <= 60) {
      timerColor = Colors.amber.shade800;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isExpired ? Colors.grey.shade300 : timerColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      color: isExpired
          ? Colors.grey.shade50
          : timerColor.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Countdown
            Row(
              children: [
                StatusBadge.forAssignment(offer.status),
                const SizedBox(width: 8),
                if (req != null) PriorityBadge(priority: req.priority),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpired ? Colors.grey.shade200 : timerColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: timerColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer, size: 14, color: timerColor),
                      const SizedBox(width: 4),
                      Text(
                        isExpired
                            ? 'EXPIRED'
                            : '${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: timerColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress Bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              color: timerColor,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 14),

            // Request Details
            Text(
              req?.title ?? 'Service Request',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Category: ${req?.category ?? "General"} • Address: ${req?.serviceAddress ?? "Not provided"}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            if (req?.description != null && req!.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                req.description!,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 16),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.close, color: Colors.red, size: 16),
                  label: const Text('Decline Offer', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                  onPressed: isExpired
                      ? null
                      : () {
                          ref
                              .read(agentDashboardProvider.notifier)
                              .rejectOffer(offer.id, offer.requestId);
                        },
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Accept Offer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isExpired ? Colors.grey : Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isExpired
                      ? null
                      : () {
                          ref
                              .read(agentDashboardProvider.notifier)
                              .acceptOffer(offer.id, offer.requestId);
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

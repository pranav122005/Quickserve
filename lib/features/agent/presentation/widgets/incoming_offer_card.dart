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

    Color timerColor = const Color(0xFF10B981); // Emerald
    if (_remainingSeconds <= 30) {
      timerColor = const Color(0xFFEF4444); // Red
    } else if (_remainingSeconds <= 60) {
      timerColor = const Color(0xFFD97706); // Amber
    }

    final formattedTimer = isExpired
        ? 'EXPIRED'
        : '${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpired ? const Color(0xFFE2E8F0) : timerColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isExpired ? const Color(0xFF0F172A) : timerColor).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isExpired ? const Color(0xFFF1F5F9) : timerColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: timerColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'NEW SERVICE REQUEST',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (req != null) PriorityBadge(priority: req.priority),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: timerColor),
                    const SizedBox(width: 4),
                    Text(
                      'Expires in: $formattedTimer',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: timerColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Linear Progress Bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFE2E8F0),
            color: timerColor,
            minHeight: 3,
          ),

          // Card Content
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        req?.title ?? 'Service Request',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    StatusBadge.forAssignment(offer.status),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.category_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      'Service: ${req?.category ?? "General"}',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (req?.serviceAddress != null && req!.serviceAddress.isNotEmpty)
                                ? req.serviceAddress
                                : 'Location not provided',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (req?.location != null)
                            Text(
                              '${req!.location!.latitude.toStringAsFixed(4)}, ${req.location!.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (req?.description != null && req!.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    req.description!,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 16),

                // Accept / Reject Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 18),
                        label: const Text('Reject', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isExpired
                            ? null
                            : () {
                                ref.read(agentDashboardProvider.notifier).rejectOffer(offer.id, offer.requestId);
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isExpired ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: isExpired
                            ? null
                            : () {
                                ref.read(agentDashboardProvider.notifier).acceptOffer(offer.id, offer.requestId);
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/hostel_service.dart';
import 'subscription_screen.dart';

class DunningScreen extends StatefulWidget {
  final String hostelId;
  const DunningScreen({super.key, required this.hostelId});

  @override
  State<DunningScreen> createState() => _DunningScreenState();
}

class _DunningScreenState extends State<DunningScreen> {
  bool _retrying = false;

  Future<void> _retryPayment() async {
    setState(() => _retrying = true);
    try {
      await HostelService().retryPayment(widget.hostelId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment retry initiated — you\'re all set!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Retry failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Failed')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('hostels')
            .doc(widget.hostelId)
            .snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() ?? {};
          final sub = data['subscription'] as Map<String, dynamic>? ?? {};
          final paymentRetryAt = sub['paymentRetryAt'] as Timestamp?;
          final currentPeriodEnd = sub['currentPeriodEnd'] as Timestamp?;

          // Grace period: 7 days from when payment failed
          final gracePeriodEnd =
              currentPeriodEnd?.toDate().add(const Duration(days: 7));
          final daysLeft =
              gracePeriodEnd?.difference(DateTime.now()).inDays;
          final graceExpired = daysLeft != null && daysLeft < 0;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // ── Hero icon ─────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.credit_card_off_outlined,
                    size: 48,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Your payment failed',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'We couldn\'t charge your payment method.\n'
                  'Please retry to keep your subscription active.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
              const SizedBox(height: 24),

              // ── Grace period countdown ────────────────────────────────────
              if (gracePeriodEnd != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: graceExpired
                        ? Colors.red.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: graceExpired
                          ? Colors.red.shade300
                          : Colors.orange.shade300,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            color: graceExpired
                                ? Colors.red.shade700
                                : Colors.orange.shade800,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            graceExpired
                                ? 'Grace period expired'
                                : 'Grace period ends in $daysLeft day${daysLeft == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: graceExpired
                                  ? Colors.red.shade700
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        graceExpired
                            ? 'Your subscription has been suspended. Retry now to restore access.'
                            : 'Access continues until ${DateFormat('d MMM yyyy').format(gracePeriodEnd)}. Retry before then.',
                        style: TextStyle(
                          fontSize: 13,
                          color: graceExpired
                              ? Colors.red.shade700
                              : Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              if (gracePeriodEnd != null) const SizedBox(height: 24),

              // ── What to check list ────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Things to check',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      _CheckItem(
                        icon: Icons.account_balance_wallet_outlined,
                        text:
                            'Ensure your UPI / bank account has sufficient balance',
                      ),
                      _CheckItem(
                        icon: Icons.credit_card_outlined,
                        text:
                            'Verify your card isn\'t expired or blocked for online transactions',
                      ),
                      _CheckItem(
                        icon: Icons.lock_outline,
                        text:
                            'Check if your bank requires OTP approval for the charge',
                      ),
                      _CheckItem(
                        icon: Icons.wifi_outlined,
                        text:
                            'Ensure you have a stable internet connection during retry',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Last retry timestamp ──────────────────────────────────────
              if (paymentRetryAt != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Last retry attempt: ${DateFormat('d MMM yyyy, h:mm a').format(paymentRetryAt.toDate())}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),

              // ── Retry button ──────────────────────────────────────────────
              FilledButton.icon(
                onPressed: _retrying ? null : _retryPayment,
                icon: _retrying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_retrying ? 'Retrying…' : 'Retry Payment'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 12),

              // ── Update plan ───────────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        SubscriptionScreen(hostelId: widget.hostelId),
                  ),
                ),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Switch to a Different Plan'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 24),

              // ── Contact support ───────────────────────────────────────────
              Center(
                child: TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.support_agent_outlined, size: 18),
                  label: const Text('Contact Support'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _CheckItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade800)),
          ),
        ],
      ),
    );
  }
}

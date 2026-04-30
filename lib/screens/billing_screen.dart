import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/hostel_service.dart';
import 'subscription_screen.dart';
import 'dunning_screen.dart';
import 'cancellation_flow_screen.dart';

class BillingScreen extends StatelessWidget {
  final String hostelId;
  const BillingScreen({super.key, required this.hostelId});

  @override
  Widget build(BuildContext context) {
    final svc = HostelService();

    return Scaffold(
      appBar: AppBar(title: const Text('Billing & Subscription')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('hostels')
            .doc(hostelId)
            .snapshots(),
        builder: (context, hostelSnap) {
          if (hostelSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = hostelSnap.data?.data() ?? {};
          final sub = data['subscription'] as Map<String, dynamic>? ?? {};
          final status = (sub['status'] as String? ?? 'trial').toLowerCase();
          final plan = (sub['plan'] as String? ?? 'basic').toLowerCase();
          final trialEndsAt = sub['trialEndsAt'] as Timestamp?;
          final currentPeriodEnd = sub['currentPeriodEnd'] as Timestamp?;
          final razorpayId =
              sub['razorpaySubscriptionId'] as String? ?? '';

          final bool isPaymentFailed = status == 'payment_failed';
          final bool isCancelled = status == 'cancelled';
          final bool isPaused = status == 'paused';
          final bool isTrial = status == 'trial';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Dunning banner ────────────────────────────────────────────
              if (isPaymentFailed)
                _DunningBanner(hostelId: hostelId, svc: svc),

              // ── Current plan card ─────────────────────────────────────────
              _PlanCard(
                plan: plan,
                status: status,
                trialEndsAt: trialEndsAt,
                currentPeriodEnd: currentPeriodEnd,
                isTrial: isTrial,
                isCancelled: isCancelled,
                isPaused: isPaused,
              ),
              const SizedBox(height: 16),

              // ── Payment method ────────────────────────────────────────────
              _PaymentMethodCard(
                razorpayId: razorpayId,
                isCancelled: isCancelled,
              ),
              const SizedBox(height: 16),

              // ── Actions ───────────────────────────────────────────────────
              if (!isCancelled) ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SubscriptionScreen(hostelId: hostelId),
                    ),
                  ),
                  icon: const Icon(Icons.upgrade),
                  label: const Text('Change Plan'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CancellationFlowScreen(hostelId: hostelId),
                    ),
                  ),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel Subscription'),
                ),
                const SizedBox(height: 24),
              ],

              // ── Invoice history ───────────────────────────────────────────
              _InvoiceHistory(hostelId: hostelId, svc: svc),
            ],
          );
        },
      ),
    );
  }
}

// ── Dunning inline banner ─────────────────────────────────────────────────────

class _DunningBanner extends StatelessWidget {
  final String hostelId;
  final HostelService svc;
  const _DunningBanner({required this.hostelId, required this.svc});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DunningScreen(hostelId: hostelId),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Failed',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade800,
                    ),
                  ),
                  Text(
                    'Tap to view details and retry',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.red.shade700),
          ],
        ),
      ),
    );
  }
}

// ── Current plan summary card ──────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final String plan;
  final String status;
  final Timestamp? trialEndsAt;
  final Timestamp? currentPeriodEnd;
  final bool isTrial;
  final bool isCancelled;
  final bool isPaused;

  const _PlanCard({
    required this.plan,
    required this.status,
    required this.trialEndsAt,
    required this.currentPeriodEnd,
    required this.isTrial,
    required this.isCancelled,
    required this.isPaused,
  });

  @override
  Widget build(BuildContext context) {
    final planLabel = _planLabel(plan);
    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);

    final nextDate = isTrial
        ? trialEndsAt?.toDate()
        : currentPeriodEnd?.toDate();
    final nextDateStr = nextDate != null
        ? DateFormat('d MMM yyyy').format(nextDate)
        : '—';

    final nextLabel = isTrial
        ? 'Trial ends'
        : isCancelled
            ? 'Cancelled on'
            : isPaused
                ? 'Paused until'
                : 'Next billing date';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  planLabel,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: nextLabel, value: nextDateStr),
            _InfoRow(label: 'Plan ID', value: plan.toUpperCase()),
          ],
        ),
      ),
    );
  }

  static String _planLabel(String p) => switch (p) {
        'basic' => 'Basic Plan  •  ₹499/mo',
        'pro' => 'Pro Plan  •  ₹999/mo',
        'enterprise' => 'Enterprise  •  ₹2,499/mo',
        _ => p.isEmpty ? '—' : p[0].toUpperCase() + p.substring(1),
      };

  static Color _statusColor(String s) => switch (s) {
        'active' => Colors.green,
        'trial' => Colors.blue,
        'payment_failed' => Colors.red,
        'cancelled' => Colors.grey,
        'paused' => Colors.orange,
        _ => Colors.grey,
      };

  static String _statusLabel(String s) => switch (s) {
        'active' => 'Active',
        'trial' => 'Trial',
        'payment_failed' => 'Payment Failed',
        'cancelled' => 'Cancelled',
        'paused' => 'Paused',
        _ => s,
      };
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Payment method placeholder card ───────────────────────────────────────────

class _PaymentMethodCard extends StatelessWidget {
  final String razorpayId;
  final bool isCancelled;
  const _PaymentMethodCard(
      {required this.razorpayId, required this.isCancelled});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.credit_card, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        razorpayId.isNotEmpty
                            ? 'Razorpay — $razorpayId'
                            : 'No payment method on file',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        razorpayId.isNotEmpty
                            ? 'Managed by Razorpay'
                            : 'Add a card to activate your subscription',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Invoice history ─────────────────────────────────────────────────────────────

class _InvoiceHistory extends StatelessWidget {
  final String hostelId;
  final HostelService svc;
  const _InvoiceHistory({required this.hostelId, required this.svc});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Invoice History',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: svc.watchSubscriptionInvoices(hostelId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No invoices yet',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              );
            }
            return Column(
              children: docs.map((doc) {
                final d = doc.data();
                final plan = d['plan'] as String? ?? '';
                final amount = (d['amount'] as num?)?.toInt() ?? 0;
                final status = (d['status'] as String? ?? 'paid').toLowerCase();
                final createdAt = d['createdAt'] as Timestamp?;
                final periodEnd = d['periodEnd'] as Timestamp?;

                final date = createdAt?.toDate() ?? periodEnd?.toDate();
                final dateStr = date != null
                    ? DateFormat('d MMM yyyy').format(date)
                    : '—';

                final isPaid = status == 'paid';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isPaid
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      child: Icon(
                        isPaid
                            ? Icons.receipt_long
                            : Icons.receipt_long_outlined,
                        color: isPaid
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      '${_planLabel(plan)} — ₹$amount',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(dateStr),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isPaid ? 'Paid' : 'Failed',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isPaid
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  static String _planLabel(String p) => switch (p) {
        'basic' => 'Basic',
        'pro' => 'Pro',
        'enterprise' => 'Enterprise',
        _ => p.isEmpty ? '—' : p[0].toUpperCase() + p.substring(1),
      };
}

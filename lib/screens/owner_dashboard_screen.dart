import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'owner_notifications_screen.dart';

class OwnerDashboardScreen extends StatelessWidget {
  final String hostelId;
  const OwnerDashboardScreen({super.key, required this.hostelId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('hostels')
            .doc(hostelId)
            .snapshots(),
        builder: (context, hostelSnap) {
          final hostelData = hostelSnap.data?.data() ?? {};
          final hostelName = hostelData['name'] as String? ?? 'My Hostel';
          final city = hostelData['city'] as String? ?? '';
          final sub = hostelData['subscription'] as Map<String, dynamic>? ?? {};
          final status = sub['status'] as String? ?? 'unknown';
          final trialEnd = (sub['trialEndsAt'] as Timestamp?)?.toDate();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(hostelName,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          if (city.isNotEmpty)
                            Text(city,
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Text(
                      _todayLabel(),
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 8),
                    _NotificationBell(hostelId: hostelId),
                  ],
                ),
                _TrialBanner(status: status, trialEnd: trialEnd),
                const SizedBox(height: 24),

                // ── Occupancy KPI ──────────────────────────────
                _OccupancyCard(hostelId: hostelId),
                const SizedBox(height: 16),

                // ── Financial summary ─────────────────────────
                _FinanceSummaryRow(hostelId: hostelId),
                const SizedBox(height: 16),

                // ── Alert row ─────────────────────────────────
                Text('Pending alerts',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _AlertRow(hostelId: hostelId),
                const SizedBox(height: 24),

                // ── Recent guest activity ──────────────────────
                Text('Recent guests',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _RecentGuestsCard(hostelId: hostelId),
              ],
            ),
          );
        },
      ),
    );
  }

  String _todayLabel() {
    final d = DateTime.now();
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }
}

// ─── Trial banner ─────────────────────────────────────────────────────────────

class _TrialBanner extends StatelessWidget {
  final String status;
  final DateTime? trialEnd;
  const _TrialBanner({required this.status, required this.trialEnd});

  @override
  Widget build(BuildContext context) {
    if (status != 'trial' || trialEnd == null) return const SizedBox.shrink();
    final daysLeft = trialEnd!.difference(DateTime.now()).inDays;
    final isUrgent = daysLeft <= 3;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.red.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isUrgent ? Colors.red.shade200 : Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(
            isUrgent ? Icons.warning_amber_rounded : Icons.info_outline,
            color: isUrgent ? Colors.red.shade700 : Colors.amber.shade800,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isUrgent
                ? 'Trial ends in $daysLeft day${daysLeft == 1 ? '' : 's'} — subscribe now'
                : 'Free trial: $daysLeft days remaining',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isUrgent ? Colors.red.shade800 : Colors.amber.shade900,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Occupancy card ───────────────────────────────────────────────────────────

class _OccupancyCard extends StatelessWidget {
  final String hostelId;
  const _OccupancyCard({required this.hostelId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hostels')
          .doc(hostelId)
          .collection('rooms')
          .snapshots(),
      builder: (_, snap) {
        int total = 0, occupied = 0;
        for (final d in snap.data?.docs ?? []) {
          final data = d.data();
          if (data['underMaintenance'] == true) continue;
          total += (data['totalBeds'] as num?)?.toInt() ?? 0;
          occupied += (data['occupiedBeds'] as num?)?.toInt() ?? 0;
        }
        final vacant = total - occupied;
        final pct = total == 0 ? 0.0 : occupied / total;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Big occupancy number
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Occupancy',
                        style: TextStyle(
                            fontSize: 13, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$occupied / $total beds',
                            style: TextStyle(
                                fontSize: 13, color: cs.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: cs.primaryContainer,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(cs.primary),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Vacant count
                Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: vacant > 0
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$vacant',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: vacant > 0
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                          Text('vacant',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: vacant > 0
                                      ? Colors.green.shade600
                                      : Colors.red.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Finance summary row ──────────────────────────────────────────────────────

class _FinanceSummaryRow extends StatelessWidget {
  final String hostelId;
  const _FinanceSummaryRow({required this.hostelId});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hostels')
          .doc(hostelId)
          .collection('invoices')
          .where('period', isEqualTo: period)
          .snapshots(),
      builder: (_, invoiceSnap) {
        int collected = 0, pending = 0, overdue = 0;
        for (final d in invoiceSnap.data?.docs ?? []) {
          final data = d.data();
          final amt = (data['totalWithGst'] as num?)?.toInt() ??
              (data['amount'] as num?)?.toInt() ?? 0;
          switch (data['status'] as String? ?? '') {
            case 'paid':
              collected += amt;
            case 'overdue':
              overdue += amt;
            default:
              pending += amt;
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('hostels')
              .doc(hostelId)
              .collection('expenses')
              .where('period', isEqualTo: period)
              .snapshots(),
          builder: (_, expSnap) {
            int expenses = 0;
            for (final d in expSnap.data?.docs ?? []) {
              expenses += (d.data()['amount'] as num?)?.toInt() ?? 0;
            }
            return Row(
              children: [
                Expanded(
                    child: _KpiTile(
                        label: 'Collected',
                        value: '₹$collected',
                        icon: Icons.check_circle_outline,
                        color: Colors.green)),
                const SizedBox(width: 10),
                Expanded(
                    child: _KpiTile(
                        label: 'Pending',
                        value: '₹$pending',
                        icon: Icons.schedule,
                        color: Colors.orange)),
                const SizedBox(width: 10),
                Expanded(
                    child: _KpiTile(
                        label: 'Overdue',
                        value: '₹$overdue',
                        icon: Icons.warning_amber_outlined,
                        color: Colors.red)),
                const SizedBox(width: 10),
                Expanded(
                    child: _KpiTile(
                        label: 'Expenses',
                        value: '₹$expenses',
                        icon: Icons.receipt_outlined,
                        color: Colors.purple)),
              ],
            );
          },
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ─── Alert row ────────────────────────────────────────────────────────────────

class _AlertRow extends StatelessWidget {
  final String hostelId;
  const _AlertRow({required this.hostelId});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AlertTile(
            hostelId: hostelId,
            label: 'Open complaints',
            icon: Icons.report_problem_outlined,
            collection: 'complaints',
            whereField: 'status',
            whereVal: 'open',
            color: Colors.deepOrange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AlertTile(
            hostelId: hostelId,
            label: 'Checkout requests',
            icon: Icons.exit_to_app,
            collection: 'checkout_requests',
            whereField: 'status',
            whereVal: 'pending',
            color: Colors.indigo,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AlertTile(
            hostelId: hostelId,
            label: 'Maintenance open',
            icon: Icons.build_circle_outlined,
            collection: 'maintenance_requests',
            whereField: 'status',
            whereVal: 'open',
            color: Colors.teal,
          ),
        ),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  final String hostelId;
  final String label;
  final IconData icon;
  final String collection;
  final String whereField;
  final String whereVal;
  final Color color;
  const _AlertTile({
    required this.hostelId,
    required this.label,
    required this.icon,
    required this.collection,
    required this.whereField,
    required this.whereVal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hostels')
          .doc(hostelId)
          .collection(collection)
          .where(whereField, isEqualTo: whereVal)
          .snapshots(),
      builder: (_, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                  color: count > 0
                      ? color.withValues(alpha: 0.4)
                      : cs.outlineVariant.withValues(alpha: 0.5))),
          color: count > 0 ? color.withValues(alpha: 0.06) : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: count > 0 ? color : cs.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            color: count > 0 ? color : cs.onSurfaceVariant))),
                Text(
                  '$count',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: count > 0 ? color : cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Recent guests ────────────────────────────────────────────────────────────

class _RecentGuestsCard extends StatelessWidget {
  final String hostelId;
  const _RecentGuestsCard({required this.hostelId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('hostels')
            .doc(hostelId)
            .collection('guests')
            .where('isActive', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(5)
            .snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('No active guests yet',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            );
          }
          return Column(
            children: docs.map((d) {
              final data = d.data();
              final name = data['name'] as String? ?? '';
              final room = data['roomNumber'] as String? ?? '';
              final rent = (data['rentAmount'] as num?)?.toInt() ?? 0;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: cs.onPrimaryContainer),
                  ),
                ),
                title: Text(name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Room $room'),
                trailing: Text('₹$rent/mo',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.primary)),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ─── Notification bell ────────────────────────────────────────────────────────
// Shows a live badge count of all actionable items (overdue, complaints, etc.)

class _NotificationBell extends StatelessWidget {
  final String hostelId;
  const _NotificationBell({required this.hostelId});

  @override
  Widget build(BuildContext context) {
    // Sum across 3 critical collections
    return _CountStream(
      hostelId: hostelId,
      builder: (n) => IconButton(
        tooltip: 'Alerts',
        icon: Badge(
          isLabelVisible: n > 0,
          label: Text('$n'),
          child: const Icon(Icons.notifications_outlined),
        ),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              OwnerNotificationsScreen(hostelId: hostelId),
        )),
      ),
    );
  }
}

class _CountStream extends StatelessWidget {
  final String hostelId;
  final Widget Function(int) builder;
  const _CountStream({required this.hostelId, required this.builder});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final ref = db.collection('hostels').doc(hostelId);

    return StreamBuilder<List<QuerySnapshot>>(
      stream: Stream.fromFuture(Future.wait([
        ref.collection('invoices').where('status', isEqualTo: 'overdue').get(),
        ref.collection('complaints').where('status', isEqualTo: 'open').get(),
        ref
            .collection('checkout_requests')
            .where('status', isEqualTo: 'pending')
            .get(),
      ])),
      builder: (_, snap) {
        if (!snap.hasData) return builder(0);
        final total = snap.data!.fold<int>(0, (s, q) => s + q.docs.length);
        return builder(total);
      },
    );
  }
}

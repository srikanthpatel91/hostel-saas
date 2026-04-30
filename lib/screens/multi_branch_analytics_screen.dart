import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MultiBranchAnalyticsScreen extends StatelessWidget {
  const MultiBranchAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Multi-Branch Compare')),
      body: FutureBuilder<List<_BranchSummary>>(
        future: _fetchAllBranches(uid),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final branches = snap.data ?? [];
          if (branches.isEmpty) {
            return const Center(child: Text('No branches found'));
          }
          return Column(
            children: [
              if (branches.length == 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Card(
                    color: Colors.blue.shade50,
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.add_business_outlined,
                          color: Colors.blue.shade700),
                      title: const Text('Add another branch to compare',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                          'Onboard a second hostel to see side-by-side analytics'),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: branches.length,
                  itemBuilder: (ctx, i) => _BranchCard(branch: branches[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<_BranchSummary>> _fetchAllBranches(String uid) async {
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final currentPeriod =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final hostelsSnap = await db
        .collection('hostels')
        .where('ownerId', isEqualTo: uid)
        .get();

    final futures = hostelsSnap.docs.map((hostelDoc) async {
      final hostelId = hostelDoc.id;
      final hostelName = hostelDoc.data()['name'] as String? ?? '';
      final hostelCity = hostelDoc.data()['city'] as String? ?? '';
      final hostelRef = db.collection('hostels').doc(hostelId);

      final results = await Future.wait([
        hostelRef.collection('rooms').get(),
        hostelRef
            .collection('invoices')
            .where('period', isEqualTo: currentPeriod)
            .get(),
        hostelRef.collection('expenses').get(),
        hostelRef
            .collection('complaints')
            .where('status', isEqualTo: 'open')
            .get(),
      ]);

      final rooms = results[0].docs;
      final invoices = results[1].docs;
      final expenses = results[2].docs;
      final complaints = results[3].docs;

      int totalBeds = 0, occupiedBeds = 0;
      for (final r in rooms) {
        if (r.data()['underMaintenance'] == true) continue;
        totalBeds += (r.data()['totalBeds'] as num?)?.toInt() ?? 0;
        occupiedBeds += (r.data()['occupiedBeds'] as num?)?.toInt() ?? 0;
      }

      int revenue = 0, pendingCount = 0, overdueCount = 0;
      for (final inv in invoices) {
        final d = inv.data();
        final amt = (d['totalWithGst'] as num?)?.toInt() ??
            (d['amount'] as num?)?.toInt() ?? 0;
        switch (d['status']) {
          case 'paid':
            revenue += amt;
          case 'overdue':
            overdueCount++;
          default:
            pendingCount++;
        }
      }

      int expenseTotal = 0;
      for (final exp in expenses) {
        final d = exp.data();
        final date = (d['date'] as Timestamp?)?.toDate();
        if (date == null) continue;
        final p =
            '${date.year}-${date.month.toString().padLeft(2, '0')}';
        if (p == currentPeriod) {
          expenseTotal += (d['amount'] as num?)?.toInt() ?? 0;
        }
      }

      return _BranchSummary(
        hostelId: hostelId,
        name: hostelName,
        city: hostelCity,
        occupiedBeds: occupiedBeds,
        totalBeds: totalBeds,
        revenue: revenue,
        expenses: expenseTotal,
        pendingInvoices: pendingCount,
        overdueInvoices: overdueCount,
        openComplaints: complaints.length,
      );
    }).toList();

    final summaries = await Future.wait(futures);
    summaries.sort((a, b) => b.revenue.compareTo(a.revenue));
    return summaries;
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────

class _BranchSummary {
  final String hostelId;
  final String name;
  final String city;
  final int occupiedBeds;
  final int totalBeds;
  final int revenue;
  final int expenses;
  final int pendingInvoices;
  final int overdueInvoices;
  final int openComplaints;

  const _BranchSummary({
    required this.hostelId,
    required this.name,
    required this.city,
    required this.occupiedBeds,
    required this.totalBeds,
    required this.revenue,
    required this.expenses,
    required this.pendingInvoices,
    required this.overdueInvoices,
    required this.openComplaints,
  });

  int get netProfit => revenue - expenses;
  int get occupancyPct =>
      totalBeds > 0 ? (occupiedBeds / totalBeds * 100).round() : 0;
}

// ─── Branch card ──────────────────────────────────────────────────────────────

class _BranchCard extends StatelessWidget {
  final _BranchSummary branch;
  const _BranchCard({required this.branch});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final occColor = branch.occupancyPct >= 80
        ? Colors.green
        : branch.occupancyPct >= 50
            ? Colors.orange
            : Colors.red;
    final netColor = branch.netProfit >= 0 ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.home_work,
                      size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(branch.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      if (branch.city.isNotEmpty)
                        Text(branch.city,
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: occColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${branch.occupancyPct}% full',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: occColor,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                _StatTile(
                    label: 'Revenue',
                    value: '₹${branch.revenue}',
                    color: Colors.teal),
                _StatTile(
                    label: 'Expenses',
                    value: '₹${branch.expenses}',
                    color: Colors.red.shade400),
                _StatTile(
                    label: 'Net',
                    value:
                        '${branch.netProfit >= 0 ? "+" : ""}₹${branch.netProfit}',
                    color: netColor),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatTile(
                    label: 'Beds',
                    value:
                        '${branch.occupiedBeds}/${branch.totalBeds}',
                    color: cs.primary),
                _StatTile(
                    label: 'Pending',
                    value: '${branch.pendingInvoices}',
                    color: Colors.orange.shade700),
                _StatTile(
                    label: 'Overdue',
                    value: '${branch.overdueInvoices}',
                    color: Colors.red),
              ],
            ),
            if (branch.openComplaints > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.report_problem_outlined,
                        size: 15, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    Text(
                      '${branch.openComplaints} open complaint${branch.openComplaints > 1 ? "s" : ""}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.deepOrange),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: color)),
        ],
      ),
    );
  }
}

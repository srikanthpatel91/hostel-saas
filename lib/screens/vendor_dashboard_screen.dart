import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Service Provider / Vendor dashboard.
/// Vendors (laundry, bike wash, cleaning, etc.) see their incoming
/// service requests, accept/complete them, and track earnings.
class VendorDashboardScreen extends StatefulWidget {
  final String uid;
  const VendorDashboardScreen({super.key, required this.uid});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Service Dashboard'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'New Requests'),
            Tab(text: 'Active'),
            Tab(text: 'Earnings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _RequestsTab(uid: widget.uid, statusFilter: 'pending'),
          _RequestsTab(uid: widget.uid, statusFilter: 'accepted'),
          _EarningsTab(uid: widget.uid),
        ],
      ),
    );
  }
}

class _RequestsTab extends StatelessWidget {
  final String uid;
  final String statusFilter;
  const _RequestsTab({required this.uid, required this.statusFilter});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collectionGroup('serviceRequests')
          .where('vendorUid', isEqualTo: uid)
          .where('status', isEqualTo: statusFilter)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              statusFilter == 'pending' ? 'No new requests' : 'No active jobs',
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, idx) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _RequestCard(doc: docs[i], vendorUid: uid),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String vendorUid;
  const _RequestCard({required this.doc, required this.vendorUid});

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final status = d['status'] as String? ?? 'pending';
    final serviceName = d['serviceName'] as String? ?? 'Service';
    final guestName = d['guestName'] as String? ?? 'Guest';
    final price = d['price'] as String? ?? '₹0';
    final slot = d['slot'] as String? ?? '';
    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(serviceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('$guestName • $slot', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      if (createdAt != null)
                        Text(DateFormat('dd MMM, hh:mm a').format(createdAt),
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (status == 'pending')
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _updateStatus(doc.reference, 'accepted'),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Accept'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ),
                if (status == 'pending') const SizedBox(width: 8),
                if (status == 'pending')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updateStatus(doc.reference, 'rejected'),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Decline'),
                    ),
                  ),
                if (status == 'accepted')
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _updateStatus(doc.reference, 'completed'),
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('Mark Complete'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(DocumentReference ref, String status) async {
    await ref.update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == 'completed') 'completedAt': FieldValue.serverTimestamp(),
    });
  }
}

class _EarningsTab extends StatelessWidget {
  final String uid;
  const _EarningsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final monthStart = Timestamp.fromDate(DateTime(now.year, now.month));
    final fmt = NumberFormat('#,##0', 'en_IN');

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: db
          .collectionGroup('serviceRequests')
          .where('vendorUid', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isGreaterThanOrEqualTo: monthStart)
          .get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        double total = 0;
        double platformFee = 0;
        for (final d in docs) {
          final priceStr = d.data()['price'] as String? ?? '₹0';
          final amount = double.tryParse(priceStr.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
          total += amount;
          platformFee += amount * 0.1; // 10% platform fee
        }
        final payout = total - platformFee;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Earnings summary
            Card(
              color: Colors.green.withAlpha(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('This Month Earnings', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('₹${fmt.format(payout)}',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 4),
                    Text('${docs.length} jobs completed', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _EarRow('Gross Revenue', '₹${fmt.format(total)}'),
                    _EarRow('Platform Fee (10%)', '−₹${fmt.format(platformFee)}'),
                    const Divider(),
                    _EarRow('Net Payout', '₹${fmt.format(payout)}', bold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Completed Jobs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...docs.map((d) {
              final data = d.data();
              final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
              return ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                title: Text(data['serviceName'] as String? ?? ''),
                subtitle: completedAt != null ? Text(DateFormat('dd MMM').format(completedAt)) : null,
                trailing: Text(data['price'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
              );
            }),
            if (docs.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No completed jobs this month', style: TextStyle(color: Colors.grey)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EarRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _EarRow(this.label, this.value, {this.bold = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerNotificationsScreen extends StatelessWidget {
  final String hostelId;
  const OwnerNotificationsScreen({super.key, required this.hostelId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts & Notifications'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AlertSection(
            hostelId: hostelId,
            title: 'Overdue invoices',
            subtitle: 'Tenants who have not paid',
            icon: Icons.warning_amber_rounded,
            color: Colors.red,
            collection: 'invoices',
            whereField: 'status',
            whereVal: 'overdue',
            itemBuilder: _invoiceItem,
          ),
          const SizedBox(height: 16),
          _AlertSection(
            hostelId: hostelId,
            title: 'Payment proofs to review',
            subtitle: 'Tenants uploaded receipts — mark as paid',
            icon: Icons.attach_file,
            color: Colors.teal,
            collection: 'invoices',
            whereField: 'status',
            whereVal: 'pending',
            extraFilter: (docs) =>
                docs.where((d) => d.data()['receiptUrl'] != null).toList(),
            itemBuilder: _receiptItem,
          ),
          const SizedBox(height: 16),
          _AlertSection(
            hostelId: hostelId,
            title: 'Open complaints',
            subtitle: 'Raised by tenants — needs action',
            icon: Icons.report_problem_outlined,
            color: Colors.deepOrange,
            collection: 'complaints',
            whereField: 'status',
            whereVal: 'open',
            itemBuilder: _complaintItem,
          ),
          const SizedBox(height: 16),
          _AlertSection(
            hostelId: hostelId,
            title: 'Pending checkout requests',
            subtitle: 'Tenants waiting for approval',
            icon: Icons.exit_to_app,
            color: Colors.indigo,
            collection: 'checkout_requests',
            whereField: 'status',
            whereVal: 'pending',
            itemBuilder: _checkoutItem,
          ),
          const SizedBox(height: 16),
          _AlertSection(
            hostelId: hostelId,
            title: 'Open maintenance',
            subtitle: 'Repair requests not yet resolved',
            icon: Icons.build_circle_outlined,
            color: Colors.brown,
            collection: 'maintenance_requests',
            whereField: 'status',
            whereVal: 'open',
            itemBuilder: _maintenanceItem,
          ),
        ],
      ),
    );
  }

  static Widget _invoiceItem(
      BuildContext ctx, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final name = d['guestName'] as String? ?? '';
    final room = d['roomNumber'] as String? ?? '';
    final amount = (d['totalWithGst'] as num?)?.toInt() ??
        (d['amount'] as num?)?.toInt() ?? 0;
    final period = d['period'] as String? ?? '';
    return _AlertTile(
      title: name,
      subtitle: 'Room $room • $period',
      trailing: '₹$amount',
      trailingColor: Colors.red,
    );
  }

  static Widget _receiptItem(
      BuildContext ctx, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final name = d['guestName'] as String? ?? '';
    final room = d['roomNumber'] as String? ?? '';
    final fileName = d['receiptFileName'] as String? ?? 'Receipt';
    return _AlertTile(
      title: name,
      subtitle: 'Room $room • $fileName',
      trailing: 'Review',
      trailingColor: Colors.teal,
    );
  }

  static Widget _complaintItem(
      BuildContext ctx, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final title = d['title'] as String? ?? '';
    final room = d['roomNumber'] as String? ?? '';
    return _AlertTile(
      title: title.isEmpty ? 'Complaint' : title,
      subtitle: 'Room $room',
      trailing: 'Open',
      trailingColor: Colors.deepOrange,
    );
  }

  static Widget _checkoutItem(
      BuildContext ctx, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final name = d['guestName'] as String? ?? '';
    final room = d['roomNumber'] as String? ?? '';
    final moveOut = (d['expectedMoveOut'] as Timestamp?)?.toDate();
    return _AlertTile(
      title: name,
      subtitle: room.isNotEmpty ? 'Room $room' : 'Checkout pending',
      trailing: moveOut != null
          ? '${moveOut.day}/${moveOut.month}'
          : 'Pending',
      trailingColor: Colors.indigo,
    );
  }

  static Widget _maintenanceItem(
      BuildContext ctx, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final title = d['title'] as String? ?? '';
    final room = d['roomNumber'] ?? d['location'] as String? ?? '';
    return _AlertTile(
      title: title.isEmpty ? 'Maintenance' : title,
      subtitle: room.isNotEmpty ? 'Room $room' : 'Open',
      trailing: 'Open',
      trailingColor: Colors.brown,
    );
  }
}

// ─── Alert Section ────────────────────────────────────────────────────────────

class _AlertSection extends StatelessWidget {
  final String hostelId;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String collection;
  final String whereField;
  final String whereVal;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> Function(
      List<QueryDocumentSnapshot<Map<String, dynamic>>>)? extraFilter;
  final Widget Function(
      BuildContext, QueryDocumentSnapshot<Map<String, dynamic>>) itemBuilder;

  const _AlertSection({
    required this.hostelId,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.collection,
    required this.whereField,
    required this.whereVal,
    this.extraFilter,
    required this.itemBuilder,
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
      builder: (ctx, snap) {
        var docs = snap.data?.docs ?? [];
        if (extraFilter != null) docs = extraFilter!(docs);

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: docs.isEmpty
                  ? cs.outlineVariant.withValues(alpha: 0.4)
                  : color.withValues(alpha: 0.3),
            ),
          ),
          color: docs.isEmpty ? null : color.withValues(alpha: 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Icon(icon,
                        size: 18,
                        color: docs.isEmpty ? cs.onSurfaceVariant : color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: docs.isEmpty
                                    ? cs.onSurfaceVariant
                                    : cs.onSurface,
                              )),
                          Text(subtitle,
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              )),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: docs.isEmpty
                            ? cs.surfaceContainerHighest
                            : color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${docs.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: docs.isEmpty ? cs.onSurfaceVariant : color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (docs.isNotEmpty) ...[
                const Divider(height: 1),
                ...docs.map((d) => itemBuilder(ctx, d)),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Alert Tile ───────────────────────────────────────────────────────────────

class _AlertTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;
  final Color trailingColor;
  const _AlertTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.trailingColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 11)),
      trailing: Text(trailing,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: trailingColor)),
    );
  }
}

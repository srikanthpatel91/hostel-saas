import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Smart Procurement — shows auto-PO suggestions when stock < 3 days,
/// multi-supplier price comparison, and manual PO creation.
class ProcurementScreen extends StatefulWidget {
  final String hostelId;
  const ProcurementScreen({super.key, required this.hostelId});

  @override
  State<ProcurementScreen> createState() => _ProcurementScreenState();
}

class _ProcurementScreenState extends State<ProcurementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _db = FirebaseFirestore.instance;

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
        title: const Text('Smart Procurement'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Auto-PO Alerts'),
            Tab(text: 'Suppliers'),
            Tab(text: 'PO History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _AutoPoTab(hostelId: widget.hostelId, db: _db),
          _SuppliersTab(hostelId: widget.hostelId, db: _db),
          _PoHistoryTab(hostelId: widget.hostelId, db: _db),
        ],
      ),
    );
  }
}

// ─── Auto-PO Alerts ────────────────────────────────────────────────────────

class _AutoPoTab extends StatelessWidget {
  final String hostelId;
  final FirebaseFirestore db;
  const _AutoPoTab({required this.hostelId, required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('hostels').doc(hostelId).collection('inventory').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];

        // Rule: IF daysLeft <= 3 → auto-PO alert
        final urgent = docs.where((d) {
          final days = (d.data()['daysLeft'] as num?)?.toDouble() ?? 99;
          return days <= 3;
        }).toList();

        final warning = docs.where((d) {
          final days = (d.data()['daysLeft'] as num?)?.toDouble() ?? 99;
          return days > 3 && days <= 7;
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text('No inventory items. Add items in Inventory screen.'));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (urgent.isNotEmpty) ...[
              _AlertBanner(
                icon: Icons.emergency_outlined,
                color: Colors.red,
                title: '${urgent.length} items need immediate reorder',
                subtitle: 'Stock will run out in ≤ 3 days',
              ),
              const SizedBox(height: 12),
              ...urgent.map((d) => _PoSuggestionCard(
                hostelId: hostelId,
                doc: d,
                urgency: 'urgent',
                db: db,
              )),
            ],
            if (warning.isNotEmpty) ...[
              const SizedBox(height: 8),
              _AlertBanner(
                icon: Icons.warning_amber_outlined,
                color: Colors.orange,
                title: '${warning.length} items running low',
                subtitle: 'Stock will run out in 4–7 days',
              ),
              const SizedBox(height: 12),
              ...warning.map((d) => _PoSuggestionCard(
                hostelId: hostelId,
                doc: d,
                urgency: 'warning',
                db: db,
              )),
            ],
            if (urgent.isEmpty && warning.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                      SizedBox(height: 12),
                      Text('All stock levels are healthy!', style: TextStyle(fontSize: 16, color: Colors.green)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  const _AlertBanner({required this.icon, required this.color, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: TextStyle(color: color.withAlpha(180), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PoSuggestionCard extends StatefulWidget {
  final String hostelId;
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final String urgency;
  final FirebaseFirestore db;
  const _PoSuggestionCard({required this.hostelId, required this.doc, required this.urgency, required this.db});

  @override
  State<_PoSuggestionCard> createState() => _PoSuggestionCardState();
}

class _PoSuggestionCardState extends State<_PoSuggestionCard> {
  bool _placing = false;

  Future<void> _placePO() async {
    setState(() => _placing = true);
    final d = widget.doc.data()!;
    final reorderQty = (d['reorderQuantity'] as num?)?.toDouble() ?? 10;
    await widget.db
        .collection('hostels').doc(widget.hostelId)
        .collection('purchaseOrders')
        .add({
      'inventoryId': widget.doc.id,
      'itemName': d['name'] ?? '',
      'unit': d['unit'] ?? 'kg',
      'quantity': reorderQty,
      'estimatedCost': (d['unitCost'] as num?)?.toDouble() ?? 0 * reorderQty,
      'status': 'pending',
      'urgency': widget.urgency,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      setState(() => _placing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase order created!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc.data()!;
    final name = d['name'] as String? ?? '';
    final stock = (d['currentStock'] as num?)?.toDouble() ?? 0;
    final unit = d['unit'] as String? ?? 'kg';
    final daysLeft = (d['daysLeft'] as num?)?.toDouble() ?? 0;
    final reorderQty = (d['reorderQuantity'] as num?)?.toDouble() ?? 10;
    final unitCost = (d['unitCost'] as num?)?.toDouble() ?? 0;
    final isUrgent = widget.urgency == 'urgent';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUrgent ? Colors.red.withAlpha(80) : Colors.orange.withAlpha(80),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isUrgent ? Colors.red : Colors.orange).withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isUrgent ? '${daysLeft.toStringAsFixed(0)}d left' : '${daysLeft.toStringAsFixed(0)}d left',
                    style: TextStyle(
                      fontSize: 11,
                      color: isUrgent ? Colors.red : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _InfoChip('Stock: $stock $unit', Colors.grey),
                const SizedBox(width: 6),
                _InfoChip('Reorder: $reorderQty $unit', Colors.blue),
                if (unitCost > 0) ...[
                  const SizedBox(width: 6),
                  _InfoChip('~₹${(unitCost * reorderQty).toStringAsFixed(0)}', Colors.green),
                ],
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _placing ? null : _placePO,
                icon: _placing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.shopping_cart_outlined, size: 16),
                label: Text('Create PO — $reorderQty $unit'),
                style: FilledButton.styleFrom(
                  backgroundColor: isUrgent ? Colors.red : Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

// ─── Suppliers ─────────────────────────────────────────────────────────────

class _SuppliersTab extends StatelessWidget {
  final String hostelId;
  final FirebaseFirestore db;
  const _SuppliersTab({required this.hostelId, required this.db});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSupplier(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Supplier'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('hostels').doc(hostelId).collection('suppliers').snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No suppliers added yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: docs.length,
            separatorBuilder: (_, idx) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.store_outlined)),
                  title: Text(d['name'] as String? ?? ''),
                  subtitle: Text('${d['category'] ?? ''} • ${d['phone'] ?? ''}'),
                  trailing: d['rating'] != null
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            Text('${d['rating']}', style: const TextStyle(fontSize: 12)),
                          ],
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddSupplier(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Supplier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Supplier Name', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category (Rice, Vegetables…)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  await db.collection('hostels').doc(hostelId).collection('suppliers').add({
                    'name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'category': catCtrl.text.trim(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save Supplier'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── PO History ────────────────────────────────────────────────────────────

class _PoHistoryTab extends StatelessWidget {
  final String hostelId;
  final FirebaseFirestore db;
  const _PoHistoryTab({required this.hostelId, required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('hostels').doc(hostelId)
          .collection('purchaseOrders')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No purchase orders yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, idx) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final status = d['status'] as String? ?? 'pending';
            final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _statusColor(status).withAlpha(30),
                  child: Icon(_statusIcon(status), color: _statusColor(status), size: 20),
                ),
                title: Text('${d['itemName']} — ${d['quantity']} ${d['unit']}'),
                subtitle: Text(createdAt != null ? DateFormat('dd MMM yyyy').format(createdAt) : ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusBadge(status),
                    if (status == 'pending')
                      TextButton(
                        onPressed: () => _markReceived(docs[i].reference),
                        child: const Text('Mark Received'),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _markReceived(DocumentReference ref) async {
    await ref.update({'status': 'received', 'receivedAt': FieldValue.serverTimestamp()});
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'received': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.orange;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'received': return Icons.check_circle_outline;
      case 'cancelled': return Icons.cancel_outlined;
      default: return Icons.pending_outlined;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);
  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case 'received': c = Colors.green; break;
      case 'cancelled': c = Colors.red; break;
      default: c = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withAlpha(30), borderRadius: BorderRadius.circular(10)),
      child: Text(status, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.bold)),
    );
  }
}

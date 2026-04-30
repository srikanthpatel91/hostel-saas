import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

class InventoryScreen extends StatelessWidget {
  final String hostelId;
  const InventoryScreen({super.key, required this.hostelId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: HostelService().watchInventory(hostelId),
        builder: (context, snap) {
          final items = snap.data?.docs ?? [];
          final lowStock = items.where((d) {
            final cur = (d.data()['currentStock'] as num?)?.toInt() ?? 0;
            final max = (d.data()['maxStock'] as num?)?.toInt() ?? 1;
            return (cur / max) < 0.25;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Inventory Dashboard',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Real-time stock monitoring & predictive fulfilment.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                if (lowStock.isNotEmpty) ...[
                  _LowStockBanner(count: lowStock.length),
                  const SizedBox(height: 16),
                ],
                if (items.isEmpty)
                  _EmptyState(
                    onAdd: () => _showAddItemSheet(context),
                  )
                else
                  ...items.map(
                    (doc) => _InventoryCard(
                      doc: doc,
                      hostelId: hostelId,
                      onRestock: () => _showRestockSheet(context, doc),
                    ),
                  ),
                const SizedBox(height: 24),
                _RestockHistorySection(hostelId: hostelId),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        onPressed: () => _showAddItemSheet(context),
      ),
    );
  }

  void _showAddItemSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddInventoryItemSheet(hostelId: hostelId),
    );
  }

  void _showRestockSheet(
      BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RestockSheet(hostelId: hostelId, doc: doc),
    );
  }
}

// ── Low stock banner ────────────────────────────────────────────────────

class _LowStockBanner extends StatelessWidget {
  final int count;
  const _LowStockBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Low Stock Alert',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade800),
                ),
                Text(
                  '$count item${count == 1 ? '' : 's'} at critical level. Reorder within 48 hours.',
                  style: TextStyle(
                      fontSize: 12, color: Colors.red.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual inventory card ───────────────────────────────────────────

class _InventoryCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String hostelId;
  final VoidCallback onRestock;
  const _InventoryCard(
      {required this.doc, required this.hostelId, required this.onRestock});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final name = data['name'] as String? ?? '';
    final category = data['category'] as String? ?? '';
    final unit = data['unit'] as String? ?? '';
    final currentStock = (data['currentStock'] as num?)?.toInt() ?? 0;
    final maxStock = (data['maxStock'] as num?)?.toInt() ?? 1;
    final daysLeft = (data['daysLeft'] as num?)?.toInt();
    final nextDelivery = data['nextDelivery'] as String?;

    final pct = (maxStock > 0 ? currentStock / maxStock : 0.0).clamp(0.0, 1.0);
    final isCritical = pct < 0.25;
    final isWarning = pct >= 0.25 && pct < 0.50;

    final barColor = isCritical
        ? Colors.red
        : isWarning
            ? Colors.orange
            : Colors.teal;

    final icon = _categoryIcon(category);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: barColor.withValues(alpha: 0.12),
                  child: Icon(icon, color: barColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(category,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(pct * 100).round()}%',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: barColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (daysLeft != null)
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          isCritical ? Icons.report : Icons.analytics_outlined,
                          size: 14,
                          color: isCritical ? Colors.red : Colors.black45,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCritical
                              ? 'CRITICAL: $daysLeft day${daysLeft == 1 ? '' : 's'} left'
                              : '$daysLeft days left based on usage',
                          style: TextStyle(
                            fontSize: 12,
                            color: isCritical ? Colors.red : Colors.black54,
                            fontWeight: isCritical ? FontWeight.w700 : null,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      '$currentStock / $maxStock $unit',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                if (nextDelivery != null)
                  Row(
                    children: [
                      const Icon(Icons.event_repeat, size: 14,
                          color: Colors.teal),
                      const SizedBox(width: 4),
                      Text(
                        nextDelivery,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.teal,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Restock', style: TextStyle(fontSize: 12)),
                  onPressed: onRestock,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'pantry':
        return Icons.rice_bowl_outlined;
      case 'maintenance':
        return Icons.sanitizer_outlined;
      case 'guest amenities':
        return Icons.soap_outlined;
      case 'utilities':
        return Icons.electrical_services_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }
}

// ── Restock history ─────────────────────────────────────────────────────

class _RestockHistorySection extends StatelessWidget {
  final String hostelId;
  const _RestockHistorySection({required this.hostelId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: HostelService().watchRestockHistory(hostelId),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Restock History',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('Log of recent inventory replenishments.',
                          style: TextStyle(
                              color: Colors.black54, fontSize: 13)),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Entry'),
                  onPressed: () =>
                      _showAddRestockSheet(context, hostelId),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No restock entries yet.',
                      style: TextStyle(color: Colors.black45)),
                ),
              )
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: docs.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final d = entry.value.data();
                    final itemName = d['itemName'] as String? ?? '';
                    final category = d['category'] as String? ?? '';
                    final qty = (d['quantityAdded'] as num?)?.toInt() ?? 0;
                    final unit = d['unit'] as String? ?? '';
                    final status = d['status'] as String? ?? 'completed';
                    final addedAt =
                        (d['addedAt'] as Timestamp?)?.toDate();

                    return Column(
                      children: [
                        if (idx > 0)
                          const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          dense: true,
                          title: Text(itemName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Row(
                            children: [
                              _CategoryChip(category),
                              if (addedAt != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '${addedAt.day}/${addedAt.month}/${addedAt.year}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('+$qty $unit',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                              const SizedBox(width: 8),
                              _StatusChip(status),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showAddRestockSheet(BuildContext context, String hostelId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddRestockEntrySheet(hostelId: hostelId),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip(this.category);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        category,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.teal.shade800),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final isTransit = status == 'in_transit';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isTransit ? Colors.blue.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isTransit ? 'In Transit' : 'Completed',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isTransit ? Colors.blue.shade700 : Colors.green.shade700,
        ),
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('No inventory items yet.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Add items to track stock levels and get low-stock alerts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add First Item'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

// ── Add inventory item bottom sheet ────────────────────────────────────

class _AddInventoryItemSheet extends StatefulWidget {
  final String hostelId;
  const _AddInventoryItemSheet({required this.hostelId});

  @override
  State<_AddInventoryItemSheet> createState() => _AddInventoryItemSheetState();
}

class _AddInventoryItemSheetState extends State<_AddInventoryItemSheet> {
  final _nameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _currentCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  final _daysCtrl = TextEditingController();
  String _category = 'Pantry';
  bool _saving = false;

  static const _categories = [
    'Pantry',
    'Maintenance',
    'Guest Amenities',
    'Utilities',
    'Other',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _currentCtrl.dispose();
    _maxCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final unit = _unitCtrl.text.trim();
    final cur = int.tryParse(_currentCtrl.text.trim());
    final max = int.tryParse(_maxCtrl.text.trim());
    if (name.isEmpty || unit.isEmpty || cur == null || max == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fill all required fields')));
      return;
    }
    setState(() => _saving = true);
    try {
      await HostelService().addInventoryItem(
        hostelId: widget.hostelId,
        name: name,
        category: _category,
        unit: unit,
        currentStock: cur,
        maxStock: max,
        daysLeft: int.tryParse(_daysCtrl.text.trim()),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add Inventory Item',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
                labelText: 'Item name *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
                labelText: 'Category', border: OutlineInputBorder()),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _currentCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Current stock *',
                      border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _maxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Max stock *', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _unitCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Unit (kg/L…) *',
                      border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _daysCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Estimated days left (optional)',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Item'),
          ),
        ],
      ),
    );
  }
}

// ── Restock existing item sheet ─────────────────────────────────────────

class _RestockSheet extends StatefulWidget {
  final String hostelId;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _RestockSheet({required this.hostelId, required this.doc});

  @override
  State<_RestockSheet> createState() => _RestockSheetState();
}

class _RestockSheetState extends State<_RestockSheet> {
  final _addCtrl = TextEditingController();
  final _daysCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _addCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final qty = int.tryParse(_addCtrl.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid quantity')));
      return;
    }
    setState(() => _saving = true);
    final data = widget.doc.data();
    final curStock = (data['currentStock'] as num?)?.toInt() ?? 0;
    final maxStock = (data['maxStock'] as num?)?.toInt() ?? 100;
    final newStock = (curStock + qty).clamp(0, maxStock);
    try {
      await Future.wait([
        HostelService().updateInventoryStock(
          hostelId: widget.hostelId,
          itemId: widget.doc.id,
          currentStock: newStock,
          daysLeft: int.tryParse(_daysCtrl.text.trim()),
        ),
        HostelService().addRestockEntry(
          hostelId: widget.hostelId,
          itemName: data['name'] as String? ?? '',
          category: data['category'] as String? ?? '',
          quantityAdded: qty,
          unit: data['unit'] as String? ?? '',
        ),
      ]);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final name = data['name'] as String? ?? '';
    final unit = data['unit'] as String? ?? '';
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Restock: $name',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          TextField(
            controller: _addCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Quantity to add ($unit) *',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _daysCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Updated days left (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Confirm Restock'),
          ),
        ],
      ),
    );
  }
}

// ── Add restock entry sheet ─────────────────────────────────────────────

class _AddRestockEntrySheet extends StatefulWidget {
  final String hostelId;
  const _AddRestockEntrySheet({required this.hostelId});

  @override
  State<_AddRestockEntrySheet> createState() => _AddRestockEntrySheetState();
}

class _AddRestockEntrySheetState extends State<_AddRestockEntrySheet> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  String _category = 'Pantry';
  bool _saving = false;

  static const _categories = [
    'Pantry', 'Maintenance', 'Guest Amenities', 'Utilities', 'Other'
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final qty = int.tryParse(_qtyCtrl.text.trim());
    final unit = _unitCtrl.text.trim();
    if (name.isEmpty || qty == null || unit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fill all fields')));
      return;
    }
    setState(() => _saving = true);
    try {
      await HostelService().addRestockEntry(
        hostelId: widget.hostelId,
        itemName: name,
        category: _category,
        quantityAdded: qty,
        unit: unit,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('New Restock Entry',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
                labelText: 'Item name *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
                labelText: 'Category', border: OutlineInputBorder()),
            items: _categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Quantity added *',
                      border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _unitCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Unit *', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save Entry'),
          ),
        ],
      ),
    );
  }
}

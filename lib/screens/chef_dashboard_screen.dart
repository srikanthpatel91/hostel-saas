import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Live kitchen dashboard for chef/kitchen-head role.
/// Shows today's prep orders per meal type, ingredient checklist,
/// and CPG (Cost Per Guest) tracking.
class ChefDashboardScreen extends StatefulWidget {
  final String hostelId;
  const ChefDashboardScreen({super.key, required this.hostelId});

  @override
  State<ChefDashboardScreen> createState() => _ChefDashboardScreenState();
}

class _ChefDashboardScreenState extends State<ChefDashboardScreen> {
  final _db = FirebaseFirestore.instance;

  final String _today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  // Active guest count for CPG
  int _activeGuests = 0;
  // Today's menu
  Map<String, dynamic> _menu = {};
  // Recipes keyed by meal type
  Map<String, List<Map<String, dynamic>>> _recipes = {};
  // Prep task completion state (in-memory for session)
  final Map<String, bool> _taskDone = {};
  // Total kitchen cost today
  double _kitchenCost = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Active guests
    final guests = await _db
        .collection('hostels').doc(widget.hostelId)
        .collection('guests')
        .where('status', isEqualTo: 'active')
        .get();
    _activeGuests = guests.docs.length;

    // Today's menu
    final menuDoc = await _db
        .collection('hostels').doc(widget.hostelId)
        .collection('dailyMenus').doc(_today)
        .get();
    _menu = menuDoc.data() ?? {};

    // Recipes
    final recipeSnap = await _db
        .collection('hostels').doc(widget.hostelId)
        .collection('recipes')
        .get();

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    double totalCost = 0;
    for (final doc in recipeSnap.docs) {
      final d = doc.data();
      final type = d['mealType'] as String? ?? 'lunch';
      grouped[type] ??= [];
      grouped[type]!.add({'id': doc.id, ...d});

      // Estimate cost: sum ingredient costs if available
      final ings = (d['ingredients'] as List<dynamic>?) ?? [];
      for (final ing in ings) {
        final map = ing as Map<String, dynamic>;
        final unitCost = (map['unitCost'] as num?)?.toDouble() ?? 0;
        final qty = (map['qty'] as num?)?.toDouble() ?? 0;
        totalCost += unitCost * qty;
      }
    }
    setState(() {
      _recipes = grouped;
      _kitchenCost = totalCost;
    });
  }

  double get _cpg => _activeGuests == 0 ? 0 : _kitchenCost / _activeGuests;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chef Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // KPI row
            Row(
              children: [
                _KpiTile('Active Guests', '$_activeGuests', Icons.people_outline, Colors.blue),
                const SizedBox(width: 12),
                _KpiTile('CPG Today', '₹${_cpg.toStringAsFixed(0)}', Icons.restaurant_outlined,
                    _cpg <= 55 ? Colors.green : Colors.orange),
                const SizedBox(width: 12),
                _KpiTile('Kitchen Cost', '₹${_kitchenCost.toStringAsFixed(0)}', Icons.payments_outlined, Colors.purple),
              ],
            ),
            const SizedBox(height: 8),
            if (_cpg > 55)
              Card(
                color: Colors.orange.withAlpha(25),
                child: const ListTile(
                  leading: Icon(Icons.warning_amber_outlined, color: Colors.orange),
                  title: Text('CPG above target (₹55)', style: TextStyle(fontSize: 13)),
                  subtitle: Text('Consider recipe substitutions to reduce cost.', style: TextStyle(fontSize: 12)),
                ),
              ),
            const SizedBox(height: 16),
            // Prep orders per meal
            for (final mealType in ['breakfast', 'lunch', 'dinner']) ...[
              _MealPrepSection(
                mealType: mealType,
                menu: _menu,
                recipes: _recipes[mealType] ?? [],
                guestCount: _activeGuests,
                taskDone: _taskDone,
                onToggle: (key) => setState(() => _taskDone[key] = !(_taskDone[key] ?? false)),
              ),
              const SizedBox(height: 12),
            ],
            // Wastage alert
            _WastageCard(mealType: 'lunch', hostelId: widget.hostelId),
          ],
        ),
      ),
    );
  }
}

class _MealPrepSection extends StatelessWidget {
  final String mealType;
  final Map<String, dynamic> menu;
  final List<Map<String, dynamic>> recipes;
  final int guestCount;
  final Map<String, bool> taskDone;
  final ValueChanged<String> onToggle;
  const _MealPrepSection({
    required this.mealType, required this.menu, required this.recipes,
    required this.guestCount, required this.taskDone, required this.onToggle,
  });

  Color get _color {
    switch (mealType) {
      case 'breakfast': return Colors.orange;
      case 'dinner': return Colors.indigo;
      default: return Colors.green;
    }
  }

  IconData get _icon {
    switch (mealType) {
      case 'breakfast': return Icons.free_breakfast_outlined;
      case 'dinner': return Icons.dinner_dining_outlined;
      default: return Icons.lunch_dining_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mealData = menu[mealType] as Map<String, dynamic>?;
    final items = (mealData?['items'] as List<dynamic>?) ?? [];
    final statusNote = mealData?['statusNote'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, color: _color, size: 20),
                const SizedBox(width: 8),
                Text(mealType.capitalize(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _color)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _color.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$guestCount servings', style: TextStyle(fontSize: 11, color: _color)),
                ),
              ],
            ),
            if (statusNote != null && statusNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('⚠ $statusNote', style: const TextStyle(fontSize: 12, color: Colors.orange)),
              ),
            ],
            if (items.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Today\'s Menu', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: items.map((i) => Chip(
                  label: Text(i.toString(), style: const TextStyle(fontSize: 11)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
            ],
            if (recipes.isNotEmpty) ...[
              const Divider(height: 16),
              Text('Prep Tasks', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ...recipes.expand((recipe) {
                final name = recipe['name'] as String? ?? '';
                final ings = (recipe['ingredients'] as List<dynamic>?) ?? [];
                final servings = (recipe['servings'] as num?)?.toInt() ?? 1;
                final factor = guestCount / (servings == 0 ? 1 : servings);
                return [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 2),
                    child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  ...ings.map((ing) {
                    final m = ing as Map<String, dynamic>;
                    final qty = ((m['qty'] as num?)?.toDouble() ?? 0) * factor;
                    final key = '${mealType}_${name}_${m['name']}';
                    final done = taskDone[key] ?? false;
                    return CheckboxListTile(
                      dense: true,
                      value: done,
                      onChanged: (_) => onToggle(key),
                      title: Text(
                        '${m['name']} — ${qty.toStringAsFixed(1)} ${m['unit']}',
                        style: TextStyle(
                          fontSize: 13,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done ? Colors.grey : null,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }),
                ];
              }),
            ],
            if (recipes.isEmpty && items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('No menu or recipes set for $mealType',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ),
          ],
        ),
      ),
    );
  }
}

class _WastageCard extends StatefulWidget {
  final String mealType;
  final String hostelId;
  const _WastageCard({required this.mealType, required this.hostelId});
  @override
  State<_WastageCard> createState() => _WastageCardState();
}

class _WastageCardState extends State<_WastageCard> {
  final _wastageCtrl = TextEditingController();
  bool _saved = false;

  Future<void> _logWastage() async {
    final qty = double.tryParse(_wastageCtrl.text);
    if (qty == null || qty <= 0) return;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await FirebaseFirestore.instance
        .collection('hostels').doc(widget.hostelId)
        .collection('wastage')
        .doc('${today}_${widget.mealType}')
        .set({
      'date': today,
      'mealType': widget.mealType,
      'wastedQty': qty,
      'unit': 'kg',
      'loggedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    setState(() => _saved = true);
    _wastageCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.withAlpha(15),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.red, size: 18),
                SizedBox(width: 6),
                Text('Log Food Wastage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 8),
            if (_saved) const Text('✓ Wastage logged for today', style: TextStyle(color: Colors.green, fontSize: 13))
            else Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _wastageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Wasted quantity (kg)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _logWastage, child: const Text('Log')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _KpiTile(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
              Text(label, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

extension _Str on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

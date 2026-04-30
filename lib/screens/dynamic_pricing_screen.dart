import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Dynamic Pricing Screen — owner sets Uber-style surge pricing rules.
/// Rules are: IF occupancy > X% OR ingredient spike > Y% THEN adjust price by Z%.
class DynamicPricingScreen extends StatefulWidget {
  final String hostelId;
  const DynamicPricingScreen({super.key, required this.hostelId});

  @override
  State<DynamicPricingScreen> createState() => _DynamicPricingScreenState();
}

class _DynamicPricingScreenState extends State<DynamicPricingScreen>
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
        title: const Text('Dynamic Pricing'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Room Pricing'),
            Tab(text: 'Meal Pricing'),
            Tab(text: 'Rules'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _RoomPricingTab(hostelId: widget.hostelId, db: _db),
          _MealPricingTab(hostelId: widget.hostelId, db: _db),
          _PricingRulesTab(hostelId: widget.hostelId, db: _db),
        ],
      ),
    );
  }
}

// ─── Room Pricing ───────────────────────────────────────────────────────────

class _RoomPricingTab extends StatelessWidget {
  final String hostelId;
  final FirebaseFirestore db;
  const _RoomPricingTab({required this.hostelId, required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('hostels').doc(hostelId).collection('rooms').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No rooms found. Add rooms first.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, idx) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _RoomPriceCard(
            doc: docs[i],
            hostelId: hostelId,
            db: db,
          ),
        );
      },
    );
  }
}

class _RoomPriceCard extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final String hostelId;
  final FirebaseFirestore db;
  const _RoomPriceCard({required this.doc, required this.hostelId, required this.db});

  @override
  State<_RoomPriceCard> createState() => _RoomPriceCardState();
}

class _RoomPriceCardState extends State<_RoomPriceCard> {
  late final TextEditingController _baseCtrl;
  late final TextEditingController _surgeCtrl;
  bool _surgeEnabled = false;

  @override
  void initState() {
    super.initState();
    final d = widget.doc.data()!;
    _baseCtrl = TextEditingController(text: '${d['monthlyRent'] ?? d['basePrice'] ?? ''}');
    _surgeCtrl = TextEditingController(text: '${d['surgeMultiplier'] ?? '1.2'}');
    _surgeEnabled = d['surgeEnabled'] == true;
  }

  Future<void> _save() async {
    await widget.db.collection('hostels').doc(widget.hostelId)
        .collection('rooms').doc(widget.doc.id).update({
      'monthlyRent': int.tryParse(_baseCtrl.text) ?? 0,
      'surgeMultiplier': double.tryParse(_surgeCtrl.text) ?? 1.2,
      'surgeEnabled': _surgeEnabled,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pricing updated!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc.data()!;
    final roomNum = d['roomNumber'] as String? ?? '';
    final type = d['type'] as String? ?? '';
    final base = int.tryParse(_baseCtrl.text) ?? 0;
    final surge = double.tryParse(_surgeCtrl.text) ?? 1.2;
    final surgePrice = (base * surge).round();

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
                      Text('Room $roomNum', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(type, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Switch(
                  value: _surgeEnabled,
                  onChanged: (v) => setState(() => _surgeEnabled = v),
                ),
                Text(_surgeEnabled ? 'Surge ON' : 'Normal',
                    style: TextStyle(
                      fontSize: 12,
                      color: _surgeEnabled ? Colors.orange : Colors.grey,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _baseCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Base Rent (₹/month)',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _surgeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    enabled: _surgeEnabled,
                    decoration: const InputDecoration(
                      labelText: 'Surge Multiplier',
                      border: OutlineInputBorder(),
                      hintText: '1.2×',
                    ),
                  ),
                ),
              ],
            ),
            if (_surgeEnabled) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Effective Price (surge):', style: TextStyle(fontSize: 13)),
                    Text('₹$surgePrice/month',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('Save Pricing'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Meal Pricing ──────────────────────────────────────────────────────────

class _MealPricingTab extends StatelessWidget {
  final String hostelId;
  final FirebaseFirestore db;
  const _MealPricingTab({required this.hostelId, required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('hostels').doc(hostelId).collection('mealPlans').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No meal plans found. Add plans in Meal Plans screen.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, idx) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _MealPriceCard(doc: docs[i], hostelId: hostelId, db: db),
        );
      },
    );
  }
}

class _MealPriceCard extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final String hostelId;
  final FirebaseFirestore db;
  const _MealPriceCard({required this.doc, required this.hostelId, required this.db});

  @override
  State<_MealPriceCard> createState() => _MealPriceCardState();
}

class _MealPriceCardState extends State<_MealPriceCard> {
  late final TextEditingController _priceCtrl;
  late final TextEditingController _spikePctCtrl;
  bool _autoAdjust = false;

  @override
  void initState() {
    super.initState();
    final d = widget.doc.data()!;
    _priceCtrl = TextEditingController(text: '${d['price'] ?? ''}');
    _spikePctCtrl = TextEditingController(text: '${d['ingredientSpikeThreshold'] ?? '10'}');
    _autoAdjust = d['autoAdjust'] == true;
  }

  Future<void> _save() async {
    await widget.db.collection('hostels').doc(widget.hostelId)
        .collection('mealPlans').doc(widget.doc.id).update({
      'price': int.tryParse(_priceCtrl.text) ?? 0,
      'autoAdjust': _autoAdjust,
      'ingredientSpikeThreshold': int.tryParse(_spikePctCtrl.text) ?? 10,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal pricing updated!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc.data()!;
    final name = d['name'] as String? ?? '';

    return Card(
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
                Switch(value: _autoAdjust, onChanged: (v) => setState(() => _autoAdjust = v)),
                Text(_autoAdjust ? 'Auto' : 'Fixed',
                    style: TextStyle(fontSize: 12, color: _autoAdjust ? Colors.green : Colors.grey)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Price (₹)',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                  ),
                ),
                if (_autoAdjust) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _spikePctCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Alert if cost spike >',
                        border: OutlineInputBorder(),
                        suffixText: '%',
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (_autoAdjust) ...[
              const SizedBox(height: 6),
              Text(
                'AI will suggest price adjustment if ingredient costs rise by more than ${_spikePctCtrl.text}%',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pricing Rules ─────────────────────────────────────────────────────────

class _PricingRulesTab extends StatefulWidget {
  final String hostelId;
  final FirebaseFirestore db;
  const _PricingRulesTab({required this.hostelId, required this.db});

  @override
  State<_PricingRulesTab> createState() => _PricingRulesTabState();
}

class _PricingRulesTabState extends State<_PricingRulesTab> {
  // Default rules
  double _surgeOccupancyThreshold = 80; // % occupancy triggers surge
  double _surgePct = 20; // % price increase
  double _discountOccupancyThreshold = 40; // % below which discount kicks in
  double _discountPct = 10; // % discount
  bool _festivalSurge = true;
  bool _weekendSurge = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await widget.db.collection('hostels').doc(widget.hostelId)
        .collection('settings').doc('pricing').get();
    if (doc.exists) {
      final d = doc.data()!;
      setState(() {
        _surgeOccupancyThreshold = (d['surgeOccupancyThreshold'] as num?)?.toDouble() ?? 80;
        _surgePct = (d['surgePct'] as num?)?.toDouble() ?? 20;
        _discountOccupancyThreshold = (d['discountOccupancyThreshold'] as num?)?.toDouble() ?? 40;
        _discountPct = (d['discountPct'] as num?)?.toDouble() ?? 10;
        _festivalSurge = d['festivalSurge'] as bool? ?? true;
        _weekendSurge = d['weekendSurge'] as bool? ?? false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.db.collection('hostels').doc(widget.hostelId)
        .collection('settings').doc('pricing').set({
      'surgeOccupancyThreshold': _surgeOccupancyThreshold,
      'surgePct': _surgePct,
      'discountOccupancyThreshold': _discountOccupancyThreshold,
      'discountPct': _discountPct,
      'festivalSurge': _festivalSurge,
      'weekendSurge': _weekendSurge,
    }, SetOptions(merge: true));
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pricing rules saved!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RuleCard(
            icon: Icons.trending_up,
            color: Colors.orange,
            title: 'Surge Pricing',
            subtitle: 'Auto-increase price when demand is high',
            children: [
              _SliderRow(
                label: 'Trigger when occupancy >',
                value: _surgeOccupancyThreshold,
                min: 50,
                max: 100,
                suffix: '%',
                onChanged: (v) => setState(() => _surgeOccupancyThreshold = v),
              ),
              _SliderRow(
                label: 'Increase price by',
                value: _surgePct,
                min: 5,
                max: 50,
                suffix: '%',
                onChanged: (v) => setState(() => _surgePct = v),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Rule: IF occupancy > ${_surgeOccupancyThreshold.toInt()}% → +${_surgePct.toInt()}% surge',
                  style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RuleCard(
            icon: Icons.trending_down,
            color: Colors.blue,
            title: 'Discount Pricing',
            subtitle: 'Offer discounts to fill vacant beds',
            children: [
              _SliderRow(
                label: 'Trigger when occupancy <',
                value: _discountOccupancyThreshold,
                min: 10,
                max: 70,
                suffix: '%',
                onChanged: (v) => setState(() => _discountOccupancyThreshold = v),
              ),
              _SliderRow(
                label: 'Discount by',
                value: _discountPct,
                min: 5,
                max: 30,
                suffix: '%',
                onChanged: (v) => setState(() => _discountPct = v),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Rule: IF occupancy < ${_discountOccupancyThreshold.toInt()}% → -${_discountPct.toInt()}% discount',
                  style: const TextStyle(fontSize: 12, color: Colors.blue, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RuleCard(
            icon: Icons.celebration_outlined,
            color: Colors.purple,
            title: 'Special Periods',
            subtitle: 'Festival and weekend pricing adjustments',
            children: [
              SwitchListTile(
                value: _festivalSurge,
                onChanged: (v) => setState(() => _festivalSurge = v),
                title: const Text('Festival Surge (+15%)', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Diwali, Holi, New Year, etc.', style: TextStyle(fontSize: 12)),
                dense: true,
              ),
              SwitchListTile(
                value: _weekendSurge,
                onChanged: (v) => setState(() => _weekendSurge = v),
                title: const Text('Weekend Surge (+10%)', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Saturday and Sunday', style: TextStyle(fontSize: 12)),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: const Text('Save All Rules'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final List<Widget> children;
  const _RuleCard({required this.icon, required this.color, required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label, suffix;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  const _SliderRow({required this.label, required this.value, required this.min, required this.max, required this.suffix, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text('${value.toInt()}$suffix',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) / 5).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

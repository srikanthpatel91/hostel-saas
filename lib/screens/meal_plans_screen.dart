import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

class MealPlansScreen extends StatefulWidget {
  final String hostelId;
  const MealPlansScreen({super.key, required this.hostelId});

  @override
  State<MealPlansScreen> createState() => _MealPlansScreenState();
}

class _MealPlansScreenState extends State<MealPlansScreen> {
  // 'weekly' or 'monthly' — controls which price the cards display
  String _viewCycle = 'monthly';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Plans'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'weekly',
                    label: Text('Weekly'),
                    icon: Icon(Icons.view_week_outlined, size: 16)),
                ButtonSegment(
                    value: 'monthly',
                    label: Text('Monthly'),
                    icon: Icon(Icons.calendar_month_outlined, size: 16)),
              ],
              selected: {_viewCycle},
              onSelectionChanged: (s) =>
                  setState(() => _viewCycle = s.first),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: HostelService().watchMealPlans(widget.hostelId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _EmptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
            itemCount: docs.length,
            itemBuilder: (ctx, i) => _PlanCard(
              doc: docs[i],
              hostelId: widget.hostelId,
              viewCycle: _viewCycle,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Plan'),
        onPressed: () => _showAddSheet(context),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddPlanSheet(hostelId: widget.hostelId),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restaurant_menu_outlined,
              size: 56, color: cs.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('No meal plans yet',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 6),
          Text('Create plans to assign to guests',
              style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}

// ─── Plan Card ────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String hostelId;
  final String viewCycle;
  const _PlanCard(
      {required this.doc, required this.hostelId, required this.viewCycle});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final cs = Theme.of(context).colorScheme;
    final breakfast = data['breakfast'] as bool? ?? false;
    final lunch = data['lunch'] as bool? ?? false;
    final dinner = data['dinner'] as bool? ?? false;
    final weekly = (data['weeklyPrice'] as num?)?.toInt() ?? 0;
    final monthly = (data['monthlyPrice'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(data['name'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete plan',
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _MealChip(label: 'Breakfast', active: breakfast, cs: cs),
                _MealChip(label: 'Lunch', active: lunch, cs: cs),
                _MealChip(label: 'Dinner', active: dinner, cs: cs),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Weekly price tile
                Expanded(
                  child: _PriceTile(
                    label: 'Weekly',
                    price: weekly,
                    highlighted: viewCycle == 'weekly',
                    cs: cs,
                  ),
                ),
                const SizedBox(width: 12),
                // Monthly price tile
                Expanded(
                  child: _PriceTile(
                    label: 'Monthly',
                    price: monthly,
                    highlighted: viewCycle == 'monthly',
                    cs: cs,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete meal plan?'),
        content: const Text(
            'Guests assigned this plan will keep their assignment until re-assigned.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await HostelService()
          .deleteMealPlan(hostelId: hostelId, planId: doc.id);
    }
  }
}

class _PriceTile extends StatelessWidget {
  final String label;
  final int price;
  final bool highlighted;
  final ColorScheme cs;
  const _PriceTile(
      {required this.label,
      required this.price,
      required this.highlighted,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: highlighted ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: highlighted
            ? Border.all(color: cs.primary, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: highlighted
                      ? cs.onPrimaryContainer
                      : cs.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 2),
          Text('₹$price',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: highlighted ? cs.primary : cs.onSurface)),
        ],
      ),
    );
  }
}

class _MealChip extends StatelessWidget {
  final String label;
  final bool active;
  final ColorScheme cs;
  const _MealChip(
      {required this.label, required this.active, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle : Icons.cancel_outlined,
            size: 12,
            color: active
                ? cs.onPrimaryContainer
                : cs.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: active
                      ? cs.onPrimaryContainer
                      : cs.onSurface.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}

// ─── Add Plan Sheet ───────────────────────────────────────────────────────────

class _AddPlanSheet extends StatefulWidget {
  final String hostelId;
  const _AddPlanSheet({required this.hostelId});

  @override
  State<_AddPlanSheet> createState() => _AddPlanSheetState();
}

class _AddPlanSheetState extends State<_AddPlanSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _weeklyCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();
  bool _breakfast = true;
  bool _lunch = false;
  bool _dinner = true;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weeklyCtrl.dispose();
    _monthlyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Meal Plan',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Plan name *',
                    hintText: 'e.g. Full Board, Breakfast Only',
                    border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Text('Meals included',
                  style: Theme.of(context).textTheme.labelLarge),
              _MealToggle(
                  label: 'Breakfast',
                  icon: Icons.wb_sunny_outlined,
                  value: _breakfast,
                  onChanged: (v) => setState(() => _breakfast = v)),
              _MealToggle(
                  label: 'Lunch',
                  icon: Icons.lunch_dining_outlined,
                  value: _lunch,
                  onChanged: (v) => setState(() => _lunch = v)),
              _MealToggle(
                  label: 'Dinner',
                  icon: Icons.nightlight_outlined,
                  value: _dinner,
                  onChanged: (v) => setState(() => _dinner = v)),
              const SizedBox(height: 16),
              Text('Pricing', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weeklyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Weekly ₹ *',
                          prefixIcon: Icon(Icons.view_week_outlined),
                          border: OutlineInputBorder()),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (int.tryParse(v.trim()) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _monthlyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Monthly ₹ *',
                          prefixIcon: Icon(Icons.calendar_month_outlined),
                          border: OutlineInputBorder()),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (int.tryParse(v.trim()) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create Plan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await HostelService().addMealPlan(
        hostelId: widget.hostelId,
        name: _nameCtrl.text.trim(),
        breakfast: _breakfast,
        lunch: _lunch,
        dinner: _dinner,
        weeklyPrice: int.parse(_weeklyCtrl.text.trim()),
        monthlyPrice: int.parse(_monthlyCtrl.text.trim()),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _MealToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _MealToggle(
      {required this.label,
      required this.icon,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, size: 20),
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}

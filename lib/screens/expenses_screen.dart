import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

class ExpensesScreen extends StatefulWidget {
  final String hostelId;
  const ExpensesScreen({super.key, required this.hostelId});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String get _currentPeriod {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<void> _showAddExpense() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddExpenseSheet(hostelId: widget.hostelId),
    );
  }

  void _showSetBudget(Map<String, int> currentBudgets) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SetBudgetSheet(
        hostelId: widget.hostelId,
        period: _currentPeriod,
        currentBudgets: currentBudgets,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext ctx, String expenseId, String desc) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('"$desc" will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await HostelService().deleteExpense(hostelId: widget.hostelId, expenseId: expenseId);
  }

  Color _catColor(String cat) => switch (cat) {
        'Salary' => Colors.blue,
        'Electricity' => Colors.amber,
        'Water' => Colors.cyan,
        'Internet' => Colors.purple,
        'Maintenance' => Colors.orange,
        'Groceries' => Colors.green,
        _ => Colors.grey,
      };

  IconData _catIcon(String cat) => switch (cat) {
        'Salary' => Icons.people,
        'Electricity' => Icons.bolt,
        'Water' => Icons.water_drop,
        'Internet' => Icons.wifi,
        'Maintenance' => Icons.build,
        'Groceries' => Icons.shopping_cart,
        _ => Icons.receipt,
      };

  String _fmtDate(DateTime d) {
    const m = ['', 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
        onPressed: _showAddExpense,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: HostelService().watchExpenses(widget.hostelId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No expenses yet', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add first expense'),
                    onPressed: _showAddExpense,
                  ),
                ],
              ),
            );
          }

          // Category totals (all time)
          final Map<String, int> catTotals = {};
          int grandTotal = 0;
          for (final d in docs) {
            final cat = d.data()['category'] as String? ?? 'Other';
            final amt = (d.data()['amount'] as num?)?.toInt() ?? 0;
            catTotals[cat] = (catTotals[cat] ?? 0) + amt;
            grandTotal += amt;
          }

          // Current month totals (for budget comparison)
          final now = DateTime.now();
          final Map<String, int> monthTotals = {};
          for (final d in docs) {
            final date = (d.data()['date'] as Timestamp?)?.toDate();
            if (date == null) continue;
            if (date.year != now.year || date.month != now.month) continue;
            final cat = d.data()['category'] as String? ?? 'Other';
            final amt = (d.data()['amount'] as num?)?.toInt() ?? 0;
            monthTotals[cat] = (monthTotals[cat] ?? 0) + amt;
          }

          return Column(
            children: [
              // Summary bar
              Container(
                color: Colors.red.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total (all time)', style: TextStyle(fontSize: 11, color: Colors.red)),
                          Text('₹$grandTotal',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w800, color: Colors.red)),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 4,
                      children: catTotals.entries.take(3).map((e) => Chip(
                        label: Text('${e.key} ₹${e.value}',
                            style: const TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )).toList(),
                    ),
                  ],
                ),
              ),

              // Budget section for current month
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: HostelService().watchBudget(
                    hostelId: widget.hostelId, period: _currentPeriod),
                builder: (ctx, budgetSnap) {
                  final budgetData = budgetSnap.data?.data() ?? {};
                  final budgets = budgetData.map(
                      (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
                  if (budgets.isEmpty && monthTotals.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.bar_chart_outlined, size: 16),
                        label: const Text('Set monthly budget'),
                        onPressed: () => _showSetBudget({}),
                      ),
                    );
                  }
                  return _BudgetSection(
                    monthTotals: monthTotals,
                    budgets: budgets,
                    onEdit: () => _showSetBudget(budgets),
                  );
                },
              ),

              // Expense list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final data = docs[i].data();
                    final cat = data['category'] as String? ?? 'Other';
                    final amt = (data['amount'] as num?)?.toInt() ?? 0;
                    final desc = data['description'] as String? ?? '';
                    final date = (data['date'] as Timestamp?)?.toDate();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _catColor(cat).withValues(alpha: 0.15),
                          child: Icon(_catIcon(cat), color: _catColor(cat), size: 20),
                        ),
                        title: Text(desc.isEmpty ? cat : desc,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('$cat  •  ${date != null ? _fmtDate(date) : '-'}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('₹$amt',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: Colors.red)),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                              onPressed: () => _confirmDelete(ctx, docs[i].id, desc.isEmpty ? cat : desc),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Budget section ───────────────────────────────────────────────────────────

class _BudgetSection extends StatelessWidget {
  final Map<String, int> monthTotals;
  final Map<String, int> budgets;
  final VoidCallback onEdit;
  const _BudgetSection({
    required this.monthTotals,
    required this.budgets,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final allCats = {...budgets.keys, ...monthTotals.keys}.toList()..sort();
    final now = DateTime.now();
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
            child: Row(
              children: [
                const Icon(Icons.bar_chart_outlined, size: 16, color: Colors.teal),
                const SizedBox(width: 6),
                Text(
                  'Budget — ${months[now.month]} ${now.year}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                      minimumSize: Size.zero, padding: const EdgeInsets.all(8)),
                ),
              ],
            ),
          ),
          ...allCats.map((cat) {
            final spent = monthTotals[cat] ?? 0;
            final budget = budgets[cat] ?? 0;
            final ratio = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
            final over = budget > 0 && spent > budget;
            final barColor = over ? Colors.red : Colors.teal;

            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(cat,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                      Text(
                        budget > 0
                            ? '₹$spent / ₹$budget'
                            : '₹$spent (no budget)',
                        style: TextStyle(
                            fontSize: 11,
                            color: over ? Colors.red : Colors.grey.shade600,
                            fontWeight: over ? FontWeight.w700 : FontWeight.normal),
                      ),
                      if (over)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.warning_amber_rounded,
                              size: 14, color: Colors.red),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: budget > 0 ? ratio : 0.0,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(barColor),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─── Set Budget Sheet ─────────────────────────────────────────────────────────

class _SetBudgetSheet extends StatefulWidget {
  final String hostelId;
  final String period;
  final Map<String, int> currentBudgets;
  const _SetBudgetSheet({
    required this.hostelId,
    required this.period,
    required this.currentBudgets,
  });

  @override
  State<_SetBudgetSheet> createState() => _SetBudgetSheetState();
}

class _SetBudgetSheetState extends State<_SetBudgetSheet> {
  late final Map<String, TextEditingController> _ctrls;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final cat in HostelService.expenseCategories)
        cat: TextEditingController(
            text: widget.currentBudgets[cat]?.toString() ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final budgets = <String, int>{};
      for (final e in _ctrls.entries) {
        final v = int.tryParse(e.value.text.trim());
        if (v != null && v > 0) budgets[e.key] = v;
      }
      await HostelService()
          .saveBudget(hostelId: widget.hostelId, period: widget.period, budgets: budgets);
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_outlined, color: Colors.teal),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Set Monthly Budget',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Leave blank to skip budget for that category.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          ...HostelService.expenseCategories.map((cat) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: _ctrls[cat],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: cat,
                prefixText: '₹ ',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          )),
          FilledButton.icon(
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save budget'),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _AddExpenseSheet extends StatefulWidget {
  final String hostelId;
  const _AddExpenseSheet({required this.hostelId});

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amtCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = HostelService.expenseCategories.first;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amtCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await HostelService().addExpense(
        hostelId: widget.hostelId,
        category: _category,
        amount: int.parse(_amtCtrl.text.trim()),
        description: _descCtrl.text,
        date: _date,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmtDate(DateTime d) {
    const m = ['', 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add Expense',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                  labelText: 'Category', border: OutlineInputBorder()),
              items: HostelService.expenseCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amtCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder()),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (int.tryParse(v) == null) return 'Invalid';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _date = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Date',
                    suffixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder()),
                child: Text(_fmtDate(_date)),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save expense'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PnlReportScreen extends StatefulWidget {
  final String hostelId;
  const PnlReportScreen({super.key, required this.hostelId});

  @override
  State<PnlReportScreen> createState() => _PnlReportScreenState();
}

class _PnlReportScreenState extends State<PnlReportScreen> {
  final _db = FirebaseFirestore.instance;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;

  double _rent = 0, _food = 0, _services = 0, _otherIncome = 0;
  double _salaries = 0, _procurement = 0, _utilities = 0, _maintenance = 0, _otherExpense = 0;

  // Ledger entries for detail view
  final List<Map<String, dynamic>> _ledger = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _ledger.clear(); });

    final start = Timestamp.fromDate(_month);
    final end = Timestamp.fromDate(DateTime(_month.year, _month.month + 1));

    double rent = 0, food = 0, services = 0, otherInc = 0;
    double salaries = 0, procurement = 0, utilities = 0, maint = 0, otherExp = 0;

    // Income: invoices paid in this month
    final invoices = await _db
        .collection('hostels').doc(widget.hostelId)
        .collection('invoices')
        .where('status', isEqualTo: 'paid')
        .where('paidAt', isGreaterThanOrEqualTo: start)
        .where('paidAt', isLessThan: end)
        .get();

    for (final doc in invoices.docs) {
      final d = doc.data();
      final amt = (d['totalAmount'] as num?)?.toDouble() ?? 0;
      final type = d['type'] as String? ?? 'rent';
      if (type == 'food' || type == 'meal') {
        food += amt;
      } else if (type == 'service') {
        services += amt;
      } else if (type == 'other') {
        otherInc += amt;
      } else {
        rent += amt;
      }
      _ledger.add({
        'date': (d['paidAt'] as Timestamp?)?.toDate(),
        'desc': 'Invoice — ${d['guestName'] ?? 'Guest'}',
        'type': 'income',
        'category': type,
        'amount': amt,
      });
    }

    // Expenses
    final expenses = await _db
        .collection('hostels').doc(widget.hostelId)
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThan: end)
        .get();

    for (final doc in expenses.docs) {
      final d = doc.data();
      final amt = (d['amount'] as num?)?.toDouble() ?? 0;
      final cat = (d['category'] as String? ?? '').toLowerCase();
      if (cat.contains('salary') || cat.contains('staff')) {
        salaries += amt;
      } else if (cat.contains('food') || cat.contains('grocery') || cat.contains('kitchen')) {
        procurement += amt;
      } else if (cat.contains('util') || cat.contains('electric') || cat.contains('water')) {
        utilities += amt;
      } else if (cat.contains('maint') || cat.contains('repair')) {
        maint += amt;
      } else {
        otherExp += amt;
      }
      _ledger.add({
        'date': (d['date'] as Timestamp?)?.toDate(),
        'desc': d['description'] ?? d['category'] ?? 'Expense',
        'type': 'expense',
        'category': cat,
        'amount': amt,
      });
    }

    _ledger.sort((a, b) {
      final da = a['date'] as DateTime?;
      final db = b['date'] as DateTime?;
      if (da == null || db == null) return 0;
      return db.compareTo(da);
    });

    setState(() {
      _rent = rent; _food = food; _services = services; _otherIncome = otherInc;
      _salaries = salaries; _procurement = procurement; _utilities = utilities;
      _maintenance = maint; _otherExpense = otherExp;
      _loading = false;
    });
  }

  double get _totalIncome => _rent + _food + _services + _otherIncome;
  double get _totalExpense => _salaries + _procurement + _utilities + _maintenance + _otherExpense;
  double get _netProfit => _totalIncome - _totalExpense;
  double get _margin => _totalIncome == 0 ? 0 : (_netProfit / _totalIncome) * 100;

  void _prevMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1));
    _load();
  }

  void _nextMonth() {
    final next = DateTime(_month.year, _month.month + 1);
    if (next.isAfter(DateTime.now())) return;
    setState(() => _month = next);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0', 'en_IN');
    final isProfit = _netProfit >= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('P&L Report'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _prevMonth,
          ),
          Center(
            child: Text(
              DateFormat('MMM yyyy').format(_month),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextMonth,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Net profit hero
                  _NetProfitCard(
                    net: _netProfit,
                    margin: _margin,
                    isProfit: isProfit,
                    fmt: fmt,
                  ),
                  const SizedBox(height: 16),
                  // Income breakdown
                  _SectionCard(
                    title: 'Income',
                    color: Colors.green,
                    total: _totalIncome,
                    fmt: fmt,
                    rows: [
                      _Row('Rent', _rent, fmt),
                      _Row('Food / Meal Plans', _food, fmt),
                      _Row('Services', _services, fmt),
                      _Row('Other', _otherIncome, fmt),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Expense breakdown
                  _SectionCard(
                    title: 'Expenses',
                    color: Colors.red,
                    total: _totalExpense,
                    fmt: fmt,
                    rows: [
                      _Row('Salaries / Staff', _salaries, fmt),
                      _Row('Kitchen / Procurement', _procurement, fmt),
                      _Row('Utilities', _utilities, fmt),
                      _Row('Maintenance', _maintenance, fmt),
                      _Row('Other', _otherExpense, fmt),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // GST summary
                  _GstSummaryCard(totalIncome: _totalIncome),
                  const SizedBox(height: 16),
                  // Ledger
                  Text('Transaction Ledger', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_ledger.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('No transactions this month', style: TextStyle(color: cs.onSurface.withAlpha(120))),
                      ),
                    )
                  else
                    ..._ledger.map((e) => _LedgerTile(entry: e, fmt: fmt)),
                ],
              ),
            ),
    );
  }
}

class _NetProfitCard extends StatelessWidget {
  final double net, margin;
  final bool isProfit;
  final NumberFormat fmt;
  const _NetProfitCard({required this.net, required this.margin, required this.isProfit, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final color = isProfit ? Colors.green : Colors.red;
    return Card(
      color: color.withAlpha(25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withAlpha(80))),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(isProfit ? 'Net Profit' : 'Net Loss',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Text('₹${fmt.format(net.abs())}',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 32)),
            const SizedBox(height: 4),
            Text('${margin.toStringAsFixed(1)}% margin',
                style: TextStyle(color: color.withAlpha(180), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Color color;
  final double total;
  final NumberFormat fmt;
  final List<Widget> rows;
  const _SectionCard({required this.title, required this.color, required this.total, required this.fmt, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
                Text('₹${fmt.format(total)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
              ],
            ),
            const Divider(height: 16),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final double amount;
  final NumberFormat fmt;
  const _Row(this.label, this.amount, this.fmt);

  @override
  Widget build(BuildContext context) {
    if (amount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text('₹${fmt.format(amount)}', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _GstSummaryCard extends StatelessWidget {
  final double totalIncome;
  const _GstSummaryCard({required this.totalIncome});

  @override
  Widget build(BuildContext context) {
    // GST @ 18% (CGST 9% + SGST 9%) on taxable income
    // Hostel accommodation exempt under ₹1000/day; above that: 12% GST
    // Services: 18%
    final taxable = totalIncome * 0.18; // simplified estimate
    final cgst = taxable / 2;
    final sgst = taxable / 2;
    final fmt = NumberFormat('#,##0.00', 'en_IN');

    return Card(
      color: Colors.orange.withAlpha(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined, color: Colors.orange, size: 18),
                const SizedBox(width: 6),
                const Text('GST Estimate (18%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange)),
              ],
            ),
            const SizedBox(height: 8),
            _gRow('Taxable Amount', '₹${fmt.format(totalIncome)}'),
            _gRow('CGST (9%)', '₹${fmt.format(cgst)}'),
            _gRow('SGST (9%)', '₹${fmt.format(sgst)}'),
            const Divider(height: 12),
            _gRow('Total GST Payable', '₹${fmt.format(taxable)}', bold: true),
            const SizedBox(height: 6),
            Text('* Accommodation < ₹1000/day is exempt. Consult CA for exact filing.',
                style: TextStyle(fontSize: 11, color: Colors.orange.withAlpha(180))),
          ],
        ),
      ),
    );
  }

  Widget _gRow(String l, String v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(v, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  final NumberFormat fmt;
  const _LedgerTile({required this.entry, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final isIncome = entry['type'] == 'income';
    final date = entry['date'] as DateTime?;
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: (isIncome ? Colors.green : Colors.red).withAlpha(30),
        child: Icon(
          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          size: 16,
          color: isIncome ? Colors.green : Colors.red,
        ),
      ),
      title: Text(entry['desc'] as String, style: const TextStyle(fontSize: 13)),
      subtitle: date != null ? Text(DateFormat('dd MMM').format(date), style: const TextStyle(fontSize: 11)) : null,
      trailing: Text(
        '${isIncome ? '+' : '-'} ₹${fmt.format(entry['amount'])}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: isIncome ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}

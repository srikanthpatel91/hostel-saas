import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';
import 'invoices_list_screen.dart';
import 'subscription_screen.dart';
import 'expenses_screen.dart';
import 'deposit_tracking_screen.dart';
import 'analytics_screen.dart';

class FinancialsScreen extends StatefulWidget {
  final String hostelId;
  const FinancialsScreen({super.key, required this.hostelId});

  @override
  State<FinancialsScreen> createState() => _FinancialsScreenState();
}

class _FinancialsScreenState extends State<FinancialsScreen> {
  final _now = DateTime.now();
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedMonth = _now.month;
    _selectedYear = _now.year;
  }

  String get _period =>
      '${_selectedYear.toString().padLeft(4, '0')}-${_selectedMonth.toString().padLeft(2, '0')}';

  String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  void _prevMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
    });
  }

  void _nextMonth() {
    final isCurrentMonth =
        _selectedMonth == _now.month && _selectedYear == _now.year;
    if (isCurrentMonth) return;
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentMonth =
        _selectedMonth == _now.month && _selectedYear == _now.year;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financials'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.workspace_premium, size: 18),
            label: const Text('Subscription'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SubscriptionScreen(hostelId: widget.hostelId),
            )),
          ),
        ],
      ),
      body: Column(
        children: [
          // Month selector
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _prevMonth,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_monthName(_selectedMonth)} $_selectedYear',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.chevron_right,
                      color: isCurrentMonth ? Colors.grey : null),
                  onPressed: isCurrentMonth ? null : _nextMonth,
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: HostelService().watchInvoices(widget.hostelId),
              builder: (context, invoiceSnap) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: HostelService().watchExpenses(widget.hostelId),
                  builder: (context, expenseSnap) {
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('hostels')
                          .doc(widget.hostelId)
                          .collection('guests')
                          .where('isActive', isEqualTo: true)
                          .snapshots(),
                      builder: (context, guestSnap) {
                        if (invoiceSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        // ── Income ──
                        final allInvoices = invoiceSnap.data?.docs ?? [];
                        final periodInvoices = allInvoices
                            .where((d) => d.data()['period'] == _period)
                            .toList();

                        int collected = 0, pending = 0, overdue = 0;
                        for (final doc in periodInvoices) {
                          final amt =
                              (doc.data()['totalWithGst'] as num?)?.toInt() ??
                                  (doc.data()['amount'] as num?)?.toInt() ??
                                  0;
                          final s = doc.data()['status'] as String? ?? '';
                          if (s == 'paid') {
                            collected += amt;
                          } else if (s == 'overdue') {
                            overdue += amt;
                          } else {
                            pending += amt;
                          }
                        }

                        // ── Expenses for selected month ──
                        final allExpenses = expenseSnap.data?.docs ?? [];
                        int totalExpenses = 0;
                        final periodExpenses = allExpenses.where((d) {
                          final date =
                              (d.data()['date'] as Timestamp?)?.toDate();
                          return date != null &&
                              date.month == _selectedMonth &&
                              date.year == _selectedYear;
                        }).toList();
                        for (final d in periodExpenses) {
                          totalExpenses +=
                              (d.data()['amount'] as num?)?.toInt() ?? 0;
                        }

                        // ── Guests ──
                        final activeGuests = guestSnap.data?.docs ?? [];
                        int totalDeposits = 0, totalMonthlyRent = 0;
                        for (final d in activeGuests) {
                          totalDeposits +=
                              (d.data()['depositAmount'] as num?)?.toInt() ??
                                  0;
                          totalMonthlyRent +=
                              (d.data()['rentAmount'] as num?)?.toInt() ?? 0;
                        }

                        final netProfit = collected - totalExpenses;
                        final collectionRate =
                            (collected + pending + overdue) > 0
                                ? (collected /
                                        (collected + pending + overdue) *
                                        100)
                                    .round()
                                : 0;

                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Net P&L hero
                              _HeroCard(
                                title: netProfit >= 0
                                    ? 'Net profit'
                                    : 'Net loss',
                                amount: netProfit.abs(),
                                subtitle:
                                    'Income ₹$collected − Expenses ₹$totalExpenses',
                                color: netProfit >= 0
                                    ? Colors.teal
                                    : Colors.red,
                                icon: netProfit >= 0
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                              ),
                              const SizedBox(height: 12),

                              Row(children: [
                                Expanded(
                                  child: _SummaryCard(
                                    label: 'Collected',
                                    amount: collected,
                                    color: Colors.green,
                                    icon: Icons.check_circle_outline,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SummaryCard(
                                    label: 'Expenses',
                                    amount: totalExpenses,
                                    color: Colors.red,
                                    icon: Icons.money_off,
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 12),

                              Row(children: [
                                Expanded(
                                  child: _SummaryCard(
                                    label: 'Pending',
                                    amount: pending,
                                    color: Colors.orange,
                                    icon: Icons.schedule,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SummaryCard(
                                    label: 'Overdue',
                                    amount: overdue,
                                    color: Colors.deepOrange,
                                    icon: Icons.warning_amber,
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 12),

                              Row(children: [
                                Expanded(
                                  child: _SummaryCard(
                                    label: 'Monthly rent',
                                    amount: totalMonthlyRent,
                                    color: Colors.blue,
                                    icon: Icons.monetization_on_outlined,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SummaryCard(
                                    label: 'Deposits held',
                                    amount: totalDeposits,
                                    color: Colors.purple,
                                    icon: Icons.account_balance_wallet_outlined,
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 8),

                              Text(
                                '$collectionRate% collection rate',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),

                              // Per-tenant table
                              if (activeGuests.isNotEmpty) ...[
                                const Text('Active tenants',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                                const SizedBox(height: 8),
                                ...activeGuests.map((gDoc) {
                                  final gData = gDoc.data();
                                  final inv = periodInvoices
                                      .where((i) =>
                                          i.data()['guestId'] == gDoc.id)
                                      .firstOrNull;
                                  return _TenantFinRow(
                                    name: gData['name'] as String? ?? '',
                                    room:
                                        gData['roomNumber'] as String? ?? '',
                                    rent: (gData['rentAmount'] as num?)
                                            ?.toInt() ??
                                        0,
                                    deposit:
                                        (gData['depositAmount'] as num?)
                                                ?.toInt() ??
                                            0,
                                    invoiceStatus: inv?.data()['status']
                                        as String?,
                                  );
                                }),
                                const SizedBox(height: 16),
                              ],

                              // Quick-nav buttons
                              OutlinedButton.icon(
                                icon: const Icon(Icons.receipt_long),
                                label: const Text('View all invoices'),
                                onPressed: () =>
                                    Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => InvoicesListScreen(
                                        hostelId: widget.hostelId),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.money_off),
                                label: const Text('Manage expenses'),
                                onPressed: () =>
                                    Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ExpensesScreen(
                                        hostelId: widget.hostelId),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                icon:
                                    const Icon(Icons.account_balance_wallet),
                                label: const Text('Security deposits'),
                                onPressed: () =>
                                    Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DepositTrackingScreen(
                                        hostelId: widget.hostelId),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text('Analytics & AI CFO'),
                                onPressed: () =>
                                    Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AnalyticsScreen(
                                        hostelId: widget.hostelId),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final int amount;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _HeroCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(color: color, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    '₹$amount',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: color),
                  ),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            Icon(icon, size: 48, color: color.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '₹$amount',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _TenantFinRow extends StatelessWidget {
  final String name;
  final String room;
  final int rent;
  final int deposit;
  final String? invoiceStatus;

  const _TenantFinRow({
    required this.name,
    required this.room,
    required this.rent,
    required this.deposit,
    this.invoiceStatus,
  });

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel) = switch (invoiceStatus) {
      'paid' => (Colors.green, 'Paid'),
      'overdue' => (Colors.red, 'Overdue'),
      'pending' => (Colors.orange, 'Pending'),
      _ => (Colors.grey, 'No invoice'),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
        ),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Room $room  •  Deposit ₹$deposit'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('₹$rent',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

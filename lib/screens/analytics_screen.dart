import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/hostel_service.dart';

class AnalyticsScreen extends StatelessWidget {
  final String hostelId;
  const AnalyticsScreen({super.key, required this.hostelId});

  static List<_MonthSlot> _last6Months() {
    const abbr = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final now = DateTime.now();
    return List.generate(6, (i) {
      final d = DateTime(now.year, now.month - (5 - i));
      return _MonthSlot(
        period: '${d.year}-${d.month.toString().padLeft(2, '0')}',
        label: abbr[d.month],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: HostelService().watchInvoices(hostelId),
        builder: (context, invSnap) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: HostelService().watchExpenses(hostelId),
            builder: (context, expSnap) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('hostels')
                    .doc(hostelId)
                    .collection('rooms')
                    .snapshots(),
                builder: (context, roomSnap) {
                  if (invSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final months = _last6Months();
                  final allInvoices = invSnap.data?.docs ?? [];
                  final allExpenses = expSnap.data?.docs ?? [];
                  final allRooms = roomSnap.data?.docs ?? [];
                  final now = DateTime.now();
                  final currentPeriod =
                      '${now.year}-${now.month.toString().padLeft(2, '0')}';

                  // Income per period (paid invoices only)
                  final incomeByPeriod = <String, int>{};
                  for (final doc in allInvoices) {
                    final d = doc.data();
                    if (d['status'] != 'paid') continue;
                    final p = d['period'] as String? ?? '';
                    final amt = (d['totalWithGst'] as num?)?.toInt() ??
                        (d['amount'] as num?)?.toInt() ?? 0;
                    incomeByPeriod[p] = (incomeByPeriod[p] ?? 0) + amt;
                  }

                  // Expense per period + this month by category
                  final expenseByPeriod = <String, int>{};
                  final expenseByCategory = <String, int>{};
                  for (final doc in allExpenses) {
                    final d = doc.data();
                    final date = (d['date'] as Timestamp?)?.toDate();
                    if (date == null) continue;
                    final p =
                        '${date.year}-${date.month.toString().padLeft(2, '0')}';
                    final amt = (d['amount'] as num?)?.toInt() ?? 0;
                    expenseByPeriod[p] = (expenseByPeriod[p] ?? 0) + amt;
                    if (p == currentPeriod) {
                      final cat = d['category'] as String? ?? 'Other';
                      expenseByCategory[cat] =
                          (expenseByCategory[cat] ?? 0) + amt;
                    }
                  }

                  // Occupancy (skip maintenance rooms)
                  int totalBeds = 0, occupiedBeds = 0;
                  for (final doc in allRooms) {
                    final d = doc.data();
                    if (d['underMaintenance'] == true) continue;
                    totalBeds += (d['totalBeds'] as num?)?.toInt() ?? 0;
                    occupiedBeds += (d['occupiedBeds'] as num?)?.toInt() ?? 0;
                  }

                  // Invoice counts for current period
                  final lastM = DateTime(now.year, now.month - 1);
                  final lastPeriod =
                      '${lastM.year}-${lastM.month.toString().padLeft(2, '0')}';
                  final currentIncome = incomeByPeriod[currentPeriod] ?? 0;
                  final currentExpense = expenseByPeriod[currentPeriod] ?? 0;
                  final lastIncome = incomeByPeriod[lastPeriod] ?? 0;

                  int collected = 0, pending = 0, overdue = 0;
                  for (final doc in allInvoices) {
                    if (doc.data()['period'] != currentPeriod) continue;
                    switch (doc.data()['status']) {
                      case 'paid':
                        collected++;
                      case 'overdue':
                        overdue++;
                      default:
                        pending++;
                    }
                  }

                  // 3-month trend: months[2..4] (3, 2, 1 months ago)
                  int sumTrendIncome = 0, sumTrendExpense = 0;
                  for (final m in months.sublist(2, 5)) {
                    sumTrendIncome += incomeByPeriod[m.period] ?? 0;
                    sumTrendExpense += expenseByPeriod[m.period] ?? 0;
                  }
                  final avgIncome = sumTrendIncome ~/ 3;
                  final avgExpense = sumTrendExpense ~/ 3;

                  final overdueThisMonth = allInvoices
                      .where((d) =>
                          d.data()['period'] == currentPeriod &&
                          d.data()['status'] == 'overdue')
                      .toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _OccupancyCard(
                            occupied: occupiedBeds, total: totalBeds),
                        const SizedBox(height: 20),

                        Text(
                          'Revenue vs Expenses — Last 6 months',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        const _ChartLegend(),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 200,
                          child: _RevenueBarChart(
                            months: months,
                            incomeByPeriod: incomeByPeriod,
                            expenseByPeriod: expenseByPeriod,
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (expenseByCategory.isNotEmpty) ...[
                          Text(
                            'Expenses this month by category',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          _ExpensePieCard(
                              expenseByCategory: expenseByCategory),
                          const SizedBox(height: 20),
                        ],

                        _AiInsightCard(
                          currentIncome: currentIncome,
                          lastIncome: lastIncome,
                          currentExpense: currentExpense,
                          collected: collected,
                          pending: pending,
                          overdue: overdue,
                          expenseByCategory: expenseByCategory,
                          avgIncome: avgIncome,
                          avgExpense: avgExpense,
                        ),
                        const SizedBox(height: 16),
                        _TopDebtorsCard(overdueInvoices: overdueThisMonth),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _MonthSlot {
  final String period;
  final String label;
  const _MonthSlot({required this.period, required this.label});
}

// ─── Occupancy ───────────────────────────────────────────────────────────────

class _OccupancyCard extends StatelessWidget {
  final int occupied;
  final int total;
  const _OccupancyCard({required this.occupied, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (occupied / total * 100).round() : 0;
    final color = pct >= 80
        ? Colors.green
        : pct >= 50
            ? Colors.orange
            : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Occupancy rate',
                    style: TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 4),
                Text(
                  '$pct%',
                  style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: color),
                ),
                Text(
                  '$occupied of $total beds occupied',
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: total > 0 ? occupied / total : 0,
                    strokeWidth: 8,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.15),
                  ),
                  Center(
                    child: Icon(Icons.hotel, color: color, size: 28),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chart legend ─────────────────────────────────────────────────────────────

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: Colors.teal),
        const SizedBox(width: 4),
        const Text('Income', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 16),
        Container(
            width: 12, height: 12, color: Color(0xFFEF9A9A)), // red.300
        const SizedBox(width: 4),
        const Text('Expenses', style: TextStyle(fontSize: 12)),
      ],
    );
  }
}

// ─── Revenue bar chart ────────────────────────────────────────────────────────

class _RevenueBarChart extends StatelessWidget {
  final List<_MonthSlot> months;
  final Map<String, int> incomeByPeriod;
  final Map<String, int> expenseByPeriod;

  const _RevenueBarChart({
    required this.months,
    required this.incomeByPeriod,
    required this.expenseByPeriod,
  });

  @override
  Widget build(BuildContext context) {
    double maxY = 0;
    for (final m in months) {
      final inc = (incomeByPeriod[m.period] ?? 0).toDouble();
      final exp = (expenseByPeriod[m.period] ?? 0).toDouble();
      if (inc > maxY) maxY = inc;
      if (exp > maxY) maxY = exp;
    }

    if (maxY == 0) {
      return const Center(
        child: Text('No data yet', style: TextStyle(color: Colors.grey)),
      );
    }

    final groups = months.asMap().entries.map((entry) {
      final i = entry.key;
      final m = entry.value;
      return BarChartGroupData(
        x: i,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            toY: (incomeByPeriod[m.period] ?? 0).toDouble(),
            color: Colors.teal,
            width: 10,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: (expenseByPeriod[m.period] ?? 0).toDouble(),
            color: const Color(0xFFEF9A9A),
            width: 10,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        maxY: maxY * 1.25,
        barGroups: groups,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = rodIndex == 0 ? 'Income' : 'Expense';
              return BarTooltipItem(
                '$label\n₹${rod.toY.toInt()}',
                const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= months.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(months[i].label,
                      style: const TextStyle(fontSize: 11)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (value, meta) {
                if (value == 0) {
                  return const Text('0',
                      style: TextStyle(fontSize: 9));
                }
                if (value >= 1000) {
                  return Text(
                    '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k',
                    style: const TextStyle(fontSize: 9),
                  );
                }
                return Text(value.toInt().toString(),
                    style: const TextStyle(fontSize: 9));
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Expense pie chart ────────────────────────────────────────────────────────

class _ExpensePieCard extends StatelessWidget {
  final Map<String, int> expenseByCategory;
  const _ExpensePieCard({required this.expenseByCategory});

  static const _colors = [
    Color(0xFF1565C0), // blue.800
    Color(0xFFE65100), // deepOrange.900
    Color(0xFF6A1B9A), // purple.800
    Color(0xFFAD1457), // pink.800
    Color(0xFF00695C), // teal.800
    Color(0xFFF57F17), // amber.900
    Color(0xFF1B5E20), // green.900
  ];

  @override
  Widget build(BuildContext context) {
    final total = expenseByCategory.values.fold(0, (a, b) => a + b);
    final entries = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sections = entries.asMap().entries.map((e) {
      final color = _colors[e.key % _colors.length];
      final pct = (e.value.value / total * 100).round();
      return PieChartSectionData(
        value: e.value.value.toDouble(),
        title: '$pct%',
        color: color,
        radius: 70,
        titleStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: PieChart(PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 28,
              )),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: entries.asMap().entries.map((e) {
                  final color = _colors[e.key % _colors.length];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(e.value.key,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(
                          '₹${e.value.value}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── AI CFO insight ───────────────────────────────────────────────────────────

class _Insight {
  final IconData icon;
  final String text;
  final Color color;
  const _Insight(
      {required this.icon, required this.text, required this.color});
}

class _AiInsightCard extends StatelessWidget {
  final int currentIncome;
  final int lastIncome;
  final int currentExpense;
  final int collected;
  final int pending;
  final int overdue;
  final Map<String, int> expenseByCategory;
  final int avgIncome;
  final int avgExpense;

  const _AiInsightCard({
    required this.currentIncome,
    required this.lastIncome,
    required this.currentExpense,
    required this.collected,
    required this.pending,
    required this.overdue,
    required this.expenseByCategory,
    required this.avgIncome,
    required this.avgExpense,
  });

  List<_Insight> _insights() {
    final list = <_Insight>[];
    final total = collected + pending + overdue;

    // Revenue trend
    if (lastIncome > 0 && currentIncome > 0) {
      final delta =
          ((currentIncome - lastIncome) / lastIncome * 100).round();
      list.add(_Insight(
        icon: delta >= 0 ? Icons.trending_up : Icons.trending_down,
        text: delta >= 0
            ? 'Revenue up $delta% vs last month (₹$currentIncome)'
            : 'Revenue down ${delta.abs()}% vs last month (₹$currentIncome)',
        color: delta >= 0 ? Colors.green.shade700 : Colors.red.shade700,
      ));
    } else if (currentIncome == 0 && total == 0) {
      list.add(_Insight(
        icon: Icons.info_outline,
        text: 'No rent data this month yet',
        color: Colors.grey,
      ));
    }

    // Revenue forecast (3-month trend)
    if (avgIncome > 0) {
      list.add(_Insight(
        icon: Icons.auto_graph,
        text: 'Forecast next month: ~₹$avgIncome (3-month average)',
        color: Colors.blue.shade700,
      ));
    }

    // Collection efficiency
    if (total > 0) {
      final rate = (collected / total * 100).round();
      final color = rate >= 80
          ? Colors.green.shade700
          : rate >= 50
              ? Colors.orange.shade800
              : Colors.red.shade700;
      list.add(_Insight(
        icon: Icons.percent,
        text: overdue > 0
            ? 'Collection $rate% — $overdue overdue, follow up now'
            : 'Collection rate: $rate% ($collected/$total paid)',
        color: color,
      ));
    }

    // Expense spike alert (category > 40% of income)
    if (currentIncome > 0) {
      for (final entry in expenseByCategory.entries) {
        if (entry.value > currentIncome * 0.4) {
          final pct = (entry.value / currentIncome * 100).round();
          list.add(_Insight(
            icon: Icons.warning_amber_rounded,
            text:
                '${entry.key} spend is ₹${entry.value} — $pct% of income (high)',
            color: Colors.orange.shade800,
          ));
        }
      }
    }

    // Cash flow runway
    if (avgExpense > 0 && avgIncome > 0) {
      final ratio = avgIncome / avgExpense;
      final ratioStr = ratio.toStringAsFixed(1);
      final color = ratio >= 1.5
          ? Colors.green.shade700
          : ratio >= 1.0
              ? Colors.orange.shade800
              : Colors.red.shade700;
      list.add(_Insight(
        icon: Icons.account_balance_outlined,
        text: 'Income covers ${ratioStr}x monthly expenses (3-month avg)',
        color: color,
      ));
    }

    // Net profit / loss
    final net = currentIncome - currentExpense;
    if (currentIncome > 0 || currentExpense > 0) {
      list.add(_Insight(
        icon: net >= 0
            ? Icons.check_circle_outline
            : Icons.remove_circle_outline,
        text: net >= 0
            ? 'Net profit this month: ₹$net'
            : 'Operating loss: ₹${net.abs()} — review expenses',
        color:
            net >= 0 ? Colors.green.shade700 : Colors.red.shade700,
      ));
    }

    if (list.isEmpty) {
      list.add(_Insight(
        icon: Icons.info_outline,
        text: 'Add invoices and expenses to see AI insights',
        color: Colors.grey,
      ));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final items = _insights();
    return Card(
      color: Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome,
                    color: Colors.teal.shade700, size: 18),
                const SizedBox(width: 8),
                Text(
                  'AI CFO — Smart Insights',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.teal.shade900),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.icon, size: 16, color: item.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.text,
                          style: TextStyle(
                              fontSize: 13,
                              color: item.color,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ─── Top debtors ──────────────────────────────────────────────────────────────

class _TopDebtorsCard extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> overdueInvoices;
  const _TopDebtorsCard({required this.overdueInvoices});

  @override
  Widget build(BuildContext context) {
    if (overdueInvoices.isEmpty) return const SizedBox.shrink();
    final sorted = List.of(overdueInvoices)
      ..sort((a, b) {
        final amtA = (a.data()['totalWithGst'] as num?)?.toInt() ??
            (a.data()['amount'] as num?)?.toInt() ?? 0;
        final amtB = (b.data()['totalWithGst'] as num?)?.toInt() ??
            (b.data()['amount'] as num?)?.toInt() ?? 0;
        return amtB.compareTo(amtA);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_off_outlined,
                    color: Colors.red.shade700, size: 18),
                const SizedBox(width: 8),
                Text('Top Debtors',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.red.shade800)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${sorted.length} overdue',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...sorted.take(5).map((doc) {
              final d = doc.data();
              final name = d['guestName'] as String? ?? '';
              final room = d['roomNumber'] as String? ?? '';
              final amount =
                  (d['totalWithGst'] as num?)?.toInt() ??
                      (d['amount'] as num?)?.toInt() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.red.shade50,
                      child: Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          Text('Room $room',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black45)),
                        ],
                      ),
                    ),
                    Text('₹$amount',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade700)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

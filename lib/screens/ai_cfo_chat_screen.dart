import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Conversational AI CFO Chat Screen.
/// Rule-based NLP: parses intent from user message and queries Firestore
/// to answer financial questions like "Why did profit drop?", "What's my CPG?",
/// "Which guests are overdue?", "How's occupancy this month?"
class AiCfoChatScreen extends StatefulWidget {
  final String hostelId;
  const AiCfoChatScreen({super.key, required this.hostelId});

  @override
  State<AiCfoChatScreen> createState() => _AiCfoChatScreenState();
}

class _AiCfoChatScreenState extends State<AiCfoChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _db = FirebaseFirestore.instance;

  final List<_Message> _messages = [];
  bool _thinking = false;

  @override
  void initState() {
    super.initState();
    _addBot(
      'Hello! I\'m your AI CFO. Ask me anything about your hostel finances.\n\n'
      'Try: "How\'s this month\'s profit?", "Who are the overdue guests?", '
      '"What\'s my occupancy?", "Top expenses this month", "Cash flow forecast"',
    );
  }

  void _addBot(String text) {
    setState(() => _messages.add(_Message(text: text, isUser: false)));
    _scrollDown();
  }

  void _addUser(String text) {
    setState(() => _messages.add(_Message(text: text, isUser: true)));
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    _ctrl.clear();
    _addUser(q);
    setState(() => _thinking = true);

    final response = await _processQuery(q.toLowerCase());
    setState(() => _thinking = false);
    _addBot(response);
  }

  Future<String> _processQuery(String q) async {
    final now = DateTime.now();
    final monthStart = Timestamp.fromDate(DateTime(now.year, now.month));
    final monthEnd = Timestamp.fromDate(DateTime(now.year, now.month + 1));
    final fmt = NumberFormat('#,##0', 'en_IN');

    // ─── Intent: Profit / P&L ────────────────────────────────────────────
    if (_matches(q, ['profit', 'loss', 'p&l', 'revenue', 'income', 'earning'])) {
      return await _profitQuery(monthStart, monthEnd, fmt);
    }

    // ─── Intent: Occupancy ───────────────────────────────────────────────
    if (_matches(q, ['occupancy', 'occupied', 'vacant', 'rooms', 'beds'])) {
      return await _occupancyQuery(fmt);
    }

    // ─── Intent: Overdue / Collections ───────────────────────────────────
    if (_matches(q, ['overdue', 'unpaid', 'pending payment', 'collect', 'dues'])) {
      return await _overdueQuery(fmt);
    }

    // ─── Intent: Expenses / Costs ────────────────────────────────────────
    if (_matches(q, ['expense', 'cost', 'spending', 'spend', 'purchase'])) {
      return await _expensesQuery(monthStart, monthEnd, fmt);
    }

    // ─── Intent: CPG / Food Cost ─────────────────────────────────────────
    if (_matches(q, ['cpg', 'food cost', 'cost per guest', 'kitchen cost', 'meal cost'])) {
      return await _cpgQuery(fmt);
    }

    // ─── Intent: Cash flow forecast ──────────────────────────────────────
    if (_matches(q, ['forecast', 'cash flow', 'next month', 'predict', 'runway'])) {
      return await _forecastQuery(fmt);
    }

    // ─── Intent: Top debtors ─────────────────────────────────────────────
    if (_matches(q, ['debtor', 'who owe', 'defaulter', 'biggest overdue', 'top overdue'])) {
      return await _topDebtorsQuery(fmt);
    }

    // ─── Intent: Staff / Salary ──────────────────────────────────────────
    if (_matches(q, ['staff', 'salary', 'employee', 'payroll'])) {
      return await _staffQuery(fmt);
    }

    // ─── Intent: Inventory / Stock ───────────────────────────────────────
    if (_matches(q, ['inventory', 'stock', 'ingredients', 'low stock', 'reorder'])) {
      return await _inventoryQuery();
    }

    // ─── Fallback ────────────────────────────────────────────────────────
    return 'I can answer questions about:\n'
        '• Profit & Loss ("How\'s this month\'s profit?")\n'
        '• Occupancy ("What\'s my occupancy rate?")\n'
        '• Overdue payments ("Who hasn\'t paid?")\n'
        '• Expenses ("What are my top expenses?")\n'
        '• Food cost ("What\'s my CPG?")\n'
        '• Cash flow ("Forecast next month")\n'
        '• Inventory ("What\'s running low?")\n\n'
        'What would you like to know?';
  }

  bool _matches(String q, List<String> keywords) =>
      keywords.any((k) => q.contains(k));

  Future<String> _profitQuery(Timestamp start, Timestamp end, NumberFormat fmt) async {
    double income = 0, expense = 0;

    final invoices = await _db
        .collection('hostels').doc(widget.hostelId)
        .collection('invoices')
        .where('status', isEqualTo: 'paid')
        .where('paidAt', isGreaterThanOrEqualTo: start)
        .where('paidAt', isLessThan: end)
        .get();
    for (final d in invoices.docs) {
      income += (d.data()['totalAmount'] as num?)?.toDouble() ?? 0;
    }

    final expenses = await _db
        .collection('hostels').doc(widget.hostelId)
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThan: end)
        .get();
    for (final d in expenses.docs) {
      expense += (d.data()['amount'] as num?)?.toDouble() ?? 0;
    }

    final profit = income - expense;
    final margin = income > 0 ? (profit / income * 100) : 0;
    final isProfit = profit >= 0;

    return '📊 This month\'s P&L:\n\n'
        '💚 Total Income: ₹${fmt.format(income)}\n'
        '🔴 Total Expenses: ₹${fmt.format(expense)}\n'
        '${isProfit ? '✅' : '⚠️'} Net ${isProfit ? 'Profit' : 'Loss'}: ₹${fmt.format(profit.abs())}\n'
        '📈 Margin: ${margin.toStringAsFixed(1)}%\n\n'
        '${isProfit ? 'Great performance this month! 🎉' : 'Expenses exceeded income. Review your largest expense categories to identify savings.'}';
  }

  Future<String> _occupancyQuery(NumberFormat fmt) async {
    final beds = await _db
        .collection('hostels').doc(widget.hostelId)
        .collection('rooms')
        .get();
    int total = 0, occupied = 0;
    for (final d in beds.docs) {
      final data = d.data();
      final totalBeds = (data['totalBeds'] as num?)?.toInt() ?? 0;
      final occupiedBeds = (data['occupiedBeds'] as num?)?.toInt() ?? 0;
      total += totalBeds;
      occupied += occupiedBeds;
    }
    final pct = total > 0 ? (occupied / total * 100) : 0;

    return '🏨 Occupancy Status:\n\n'
        '🛏 Total Beds: $total\n'
        '✅ Occupied: $occupied\n'
        '⬜ Vacant: ${total - occupied}\n'
        '📊 Occupancy Rate: ${pct.toStringAsFixed(1)}%\n\n'
        '${pct >= 80 ? 'Excellent! High occupancy is driving strong revenue. 🚀' : pct >= 60 ? 'Good occupancy. Target 80%+ for optimal revenue.' : 'Low occupancy. Consider promotions or referral incentives to fill beds.'}';
  }

  Future<String> _overdueQuery(NumberFormat fmt) async {
    final overdue = await _db
        .collection('hostels').doc(widget.hostelId)
        .collection('invoices')
        .where('status', isEqualTo: 'overdue')
        .get();
    double total = 0;
    final names = <String>[];
    for (final d in overdue.docs) {
      final data = d.data();
      total += (data['totalAmount'] as num?)?.toDouble() ?? 0;
      final name = data['guestName'] as String?;
      if (name != null && !names.contains(name)) names.add(name);
    }

    if (overdue.docs.isEmpty) {
      return '✅ Great news! No overdue payments. All collections are up to date.';
    }

    return '⚠️ Overdue Payments:\n\n'
        '🔴 ${overdue.docs.length} overdue invoice${overdue.docs.length == 1 ? '' : 's'}\n'
        '💸 Total dues: ₹${fmt.format(total)}\n\n'
        'Overdue guests:\n${names.take(5).map((n) => '• $n').join('\n')}'
        '${names.length > 5 ? '\n• ...and ${names.length - 5} more' : ''}\n\n'
        '💡 Send reminders from the Invoices screen to collect dues.';
  }

  Future<String> _expensesQuery(Timestamp start, Timestamp end, NumberFormat fmt) async {
    final snap = await _db
        .collection('hostels').doc(widget.hostelId)
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThan: end)
        .get();

    final Map<String, double> cats = {};
    for (final d in snap.docs) {
      final data = d.data();
      final cat = data['category'] as String? ?? 'Other';
      cats[cat] = (cats[cat] ?? 0) + ((data['amount'] as num?)?.toDouble() ?? 0);
    }

    if (cats.isEmpty) return '📝 No expenses recorded this month.';

    final sorted = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = cats.values.fold(0.0, (a, b) => a + b);

    final lines = sorted.take(5).map((e) {
      final pct = (e.value / total * 100).toStringAsFixed(0);
      return '• ${e.key}: ₹${fmt.format(e.value)} ($pct%)';
    }).join('\n');

    return '💰 Top Expenses This Month:\n\n$lines\n\n'
        '📊 Total: ₹${fmt.format(total)}\n\n'
        '${sorted.isNotEmpty && sorted.first.value / total > 0.4 ? '⚠️ "${sorted.first.key}" is ${(sorted.first.value / total * 100).toStringAsFixed(0)}% of total expenses — worth reviewing.' : 'Expense distribution looks balanced. 👍'}';
  }

  Future<String> _cpgQuery(NumberFormat fmt) async {
    final guests = await _db
        .collection('hostels').doc(widget.hostelId)
        .collection('guests')
        .where('status', isEqualTo: 'active')
        .get();
    final guestCount = guests.docs.length;
    if (guestCount == 0) return 'No active guests found.';

    final now = DateTime.now();
    final monthStart = Timestamp.fromDate(DateTime(now.year, now.month));
    final snap = await _db
        .collection('hostels').doc(widget.hostelId)
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: monthStart)
        .get();

    double kitchenCost = 0;
    for (final d in snap.docs) {
      final cat = (d.data()['category'] as String? ?? '').toLowerCase();
      if (cat.contains('food') || cat.contains('kitchen') || cat.contains('grocery')) {
        kitchenCost += (d.data()['amount'] as num?)?.toDouble() ?? 0;
      }
    }

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final dailyCpg = guestCount > 0 ? kitchenCost / guestCount / daysInMonth : 0;

    return '🍽 Cost Per Guest (CPG):\n\n'
        '👥 Active Guests: $guestCount\n'
        '🏪 Monthly Kitchen Cost: ₹${fmt.format(kitchenCost)}\n'
        '📅 Days this month: $daysInMonth\n'
        '📊 CPG: ₹${dailyCpg.toStringAsFixed(1)}/day\n\n'
        '${dailyCpg <= 45 ? '✅ Excellent! CPG is under ₹45 target.' : dailyCpg <= 55 ? '👍 Good. CPG is within ₹45–55 target range.' : '⚠️ CPG is above ₹55 target. Consider recipe substitutions or bulk purchasing.'}';
  }

  Future<String> _forecastQuery(NumberFormat fmt) async {
    // Simple 3-month average projection
    final now = DateTime.now();
    double totalIncome = 0;
    double totalExpense = 0;
    int months = 0;

    for (int i = 1; i <= 3; i++) {
      final start = Timestamp.fromDate(DateTime(now.year, now.month - i));
      final end = Timestamp.fromDate(DateTime(now.year, now.month - i + 1));

      final inv = await _db
          .collection('hostels').doc(widget.hostelId)
          .collection('invoices')
          .where('status', isEqualTo: 'paid')
          .where('paidAt', isGreaterThanOrEqualTo: start)
          .where('paidAt', isLessThan: end)
          .get();
      for (final d in inv.docs) { totalIncome += (d.data()['totalAmount'] as num?)?.toDouble() ?? 0; }

      final exp = await _db
          .collection('hostels').doc(widget.hostelId)
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: start)
          .where('date', isLessThan: end)
          .get();
      for (final d in exp.docs) { totalExpense += (d.data()['amount'] as num?)?.toDouble() ?? 0; }

      months++;
    }

    if (months == 0 || totalIncome == 0) {
      return 'Not enough historical data for forecasting. I need at least 1 month of data.';
    }

    final avgIncome = totalIncome / months;
    final avgExpense = totalExpense / months;
    final forecastProfit = avgIncome - avgExpense;
    final ratio = avgExpense > 0 ? avgIncome / avgExpense : 0;

    return '🔮 30-Day Cash Flow Forecast:\n\n'
        '📈 Projected Income: ₹${fmt.format(avgIncome)}\n'
        '📉 Projected Expenses: ₹${fmt.format(avgExpense)}\n'
        '💰 Forecast Net: ₹${fmt.format(forecastProfit)}\n'
        '📊 Income/Expense Ratio: ${ratio.toStringAsFixed(2)}x\n\n'
        '${ratio >= 1.5 ? '✅ Strong cash flow. Ratio > 1.5x — healthy runway.' : ratio >= 1.2 ? '👍 Adequate cash flow. Keep monitoring expenses.' : '⚠️ Tight cash flow. Ratio < 1.2x — consider cutting costs or increasing collections.'}\n\n'
        '(Based on 3-month average)';
  }

  Future<String> _topDebtorsQuery(NumberFormat fmt) async {
    final overdue = await _db
        .collection('hostels').doc(widget.hostelId)
        .collection('invoices')
        .where('status', isEqualTo: 'overdue')
        .get();

    final Map<String, double> byGuest = {};
    for (final d in overdue.docs) {
      final data = d.data();
      final name = data['guestName'] as String? ?? 'Unknown';
      byGuest[name] = (byGuest[name] ?? 0) + ((data['totalAmount'] as num?)?.toDouble() ?? 0);
    }

    if (byGuest.isEmpty) return '✅ No overdue guests! All payments are up to date.';

    final sorted = byGuest.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final lines = sorted.take(5).map((e) => '• ${e.key}: ₹${fmt.format(e.value)}').join('\n');
    return '🔴 Top Overdue Guests:\n\n$lines\n\n'
        '💡 Use the Invoices screen to send payment reminders or generate new invoices.';
  }

  Future<String> _staffQuery(NumberFormat fmt) async {
    final staff = await _db
        .collection('hostels').doc(widget.hostelId)
        .collection('staff')
        .get();

    if (staff.docs.isEmpty) return 'No staff members found.';

    final roles = <String, int>{};
    for (final d in staff.docs) {
      final role = d.data()['staffRole'] as String? ?? 'staff';
      roles[role] = (roles[role] ?? 0) + 1;
    }

    final lines = roles.entries.map((e) => '• ${e.key.replaceAll('_', ' ')}: ${e.value}').join('\n');
    return '👥 Staff Overview:\n\n'
        '${staff.docs.length} total staff members\n\n$lines\n\n'
        '💡 Manage staff in the Staff Management screen.';
  }

  Future<String> _inventoryQuery() async {
    final snap = await _db
        .collection('hostels').doc(widget.hostelId)
        .collection('inventory')
        .get();

    if (snap.docs.isEmpty) return 'No inventory items found.';

    final urgent = snap.docs.where((d) {
      final days = (d.data()['daysLeft'] as num?)?.toDouble() ?? 99;
      return days <= 3;
    }).toList();

    final warning = snap.docs.where((d) {
      final days = (d.data()['daysLeft'] as num?)?.toDouble() ?? 99;
      return days > 3 && days <= 7;
    }).toList();

    if (urgent.isEmpty && warning.isEmpty) {
      return '✅ All inventory levels are healthy! No items need immediate reorder.';
    }

    String result = '📦 Inventory Alert:\n\n';
    if (urgent.isNotEmpty) {
      result += '🔴 Critical (≤3 days):\n';
      for (final d in urgent) {
        result += '• ${d.data()['name']}: ${(d.data()['daysLeft'] as num?)?.toStringAsFixed(0) ?? '?'}d left\n';
      }
    }
    if (warning.isNotEmpty) {
      result += '\n🟡 Low (4–7 days):\n';
      for (final d in warning) {
        result += '• ${d.data()['name']}: ${(d.data()['daysLeft'] as num?)?.toStringAsFixed(0) ?? '?'}d left\n';
      }
    }
    result += '\n💡 Visit Procurement screen to create purchase orders.';
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.indigo,
              child: Icon(Icons.psychology, size: 18, color: Colors.white),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI CFO', style: TextStyle(fontSize: 16)),
                Text('Your financial advisor', style: TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_thinking ? 1 : 0),
              itemBuilder: (context, i) {
                if (_thinking && i == _messages.length) {
                  return _TypingIndicator();
                }
                return _ChatBubble(msg: _messages[i]);
              },
            ),
          ),
          // Quick prompts
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                "This month's profit?",
                "Occupancy rate?",
                "Who's overdue?",
                "Top expenses",
                "Cash flow forecast",
                "Low stock items?",
                "What's my CPG?",
              ].map((p) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(p, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        _ctrl.text = p;
                        _send();
                      },
                    ),
                  )).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Input
          Padding(
            padding: EdgeInsets.only(
              left: 12, right: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Ask your AI CFO...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: _send,
                  backgroundColor: cs.primary,
                  child: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isUser;
  final DateTime time;
  _Message({required this.text, required this.isUser}) : time = DateTime.now();
}

class _ChatBubble extends StatelessWidget {
  final _Message msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: msg.isUser ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 16),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          msg.text,
          style: TextStyle(
            fontSize: 13.5,
            color: msg.isUser ? Colors.white : cs.onSurface,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(delay: 0),
            SizedBox(width: 4),
            _Dot(delay: 200),
            SizedBox(width: 4),
            _Dot(delay: 400),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey.shade400,
        shape: BoxShape.circle,
      ),
    );
  }
}

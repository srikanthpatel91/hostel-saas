import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';
import 'referral_screen.dart';

class WalletScreen extends StatelessWidget {
  final String uid;
  const WalletScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet & Rewards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Refer & Earn',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReferralScreen(uid: uid),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: HostelService().watchUserDoc(uid),
        builder: (context, snap) {
          final data = snap.data?.data() ?? {};
          final wallet = data['wallet'] as Map<String, dynamic>? ?? {};
          final available = (wallet['available'] as num?)?.toInt() ?? 0;
          final bonus = (wallet['bonus'] as num?)?.toInt() ?? 0;
          final pending = (wallet['pending'] as num?)?.toInt() ?? 0;
          final dailyAdEarnings =
              (data['dailyAdEarnings'] as num?)?.toInt() ?? 0;
          const dailyAdLimit = 200;
          final monthlyRefEarnings =
              (data['monthlyReferralEarnings'] as num?)?.toInt() ?? 0;
          const monthlyRefLimit = 3000;
          final total = available + bonus + pending;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero gradient card ──────────────────────────────────
                _WalletHeroCard(
                  total: total,
                  available: available,
                  bonus: bonus,
                  pending: pending,
                  onWithdraw: () => _showWithdrawDialog(context),
                  onUse: () => _showUseDialog(context),
                ),
                const SizedBox(height: 20),

                // ── Daily / Monthly earning goals ───────────────────────
                _EarningGoalsCard(
                  dailyEarned: dailyAdEarnings,
                  dailyLimit: dailyAdLimit,
                  monthlyEarned: monthlyRefEarnings,
                  monthlyLimit: monthlyRefLimit,
                  hasPending: pending > 0,
                  pendingAmount: pending,
                ),
                const SizedBox(height: 20),

                // ── Refer & Earn banner ─────────────────────────────────
                _ReferBanner(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReferralScreen(uid: uid),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Recent activity ─────────────────────────────────────
                _TransactionList(uid: uid),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Withdraw Funds'),
        content: const Text(
          'Razorpay payout integration is coming soon. You will be able to withdraw your earned balance directly to your bank account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showUseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Use Bonus Balance'),
        content: const Text(
          'Bonus credits can be applied when paying rent or booking services. This feature will be enabled with the Razorpay integration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ── Hero gradient balance card ───────────────────────────────────────────

class _WalletHeroCard extends StatelessWidget {
  final int total;
  final int available;
  final int bonus;
  final int pending;
  final VoidCallback onWithdraw;
  final VoidCallback onUse;

  const _WalletHeroCard({
    required this.total,
    required this.available,
    required this.bonus,
    required this.pending,
    required this.onWithdraw,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0060AD), Color(0xFF68ABFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0060AD).withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Balance',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 4),
                  ],
                ),
              ),
              const Icon(Icons.account_balance_wallet,
                  color: Colors.white38, size: 32),
            ],
          ),
          Text(
            '₹$total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          // Split cards
          Row(
            children: [
              Expanded(
                child: _SubBalanceChip(
                  label: 'Withdrawable',
                  amount: available,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SubBalanceChip(
                  label: 'Bonus (In-App)',
                  amount: bonus,
                ),
              ),
              if (pending > 0) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _SubBalanceChip(
                    label: 'Pending',
                    amount: pending,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0060AD),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Withdraw',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: onWithdraw,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                  label: const Text('Use Bonus',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: onUse,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubBalanceChip extends StatelessWidget {
  final String label;
  final int amount;
  const _SubBalanceChip({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
                color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w700,
                letterSpacing: 0.8),
          ),
          const SizedBox(height: 4),
          Text(
            '₹$amount',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

// ── Earning goals card ───────────────────────────────────────────────────

class _EarningGoalsCard extends StatelessWidget {
  final int dailyEarned;
  final int dailyLimit;
  final int monthlyEarned;
  final int monthlyLimit;
  final bool hasPending;
  final int pendingAmount;

  const _EarningGoalsCard({
    required this.dailyEarned,
    required this.dailyLimit,
    required this.monthlyEarned,
    required this.monthlyLimit,
    required this.hasPending,
    required this.pendingAmount,
  });

  @override
  Widget build(BuildContext context) {
    final dailyPct = (dailyLimit > 0 ? dailyEarned / dailyLimit : 0.0).clamp(0.0, 1.0);
    final monthlyPct =
        (monthlyLimit > 0 ? monthlyEarned / monthlyLimit : 0.0).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Earning Daily Goals',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            // Daily
            Row(
              children: [
                const Icon(Icons.ads_click, size: 18, color: Color(0xFF0060AD)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Daily Ad Earnings',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                Text(
                  '₹$dailyEarned / ₹$dailyLimit',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0060AD),
                      fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: dailyPct,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF0060AD)),
              ),
            ),
            const SizedBox(height: 16),
            // Monthly
            Row(
              children: [
                const Icon(Icons.calendar_month_outlined,
                    size: 18, color: Color(0xFF635983)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Monthly Referral',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                Text(
                  '₹$monthlyEarned / ₹$monthlyLimit',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF635983),
                      fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: monthlyPct,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF635983)),
              ),
            ),
            // Pending verification
            if (hasPending) ...[
              const Divider(height: 28),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.hourglass_top,
                        color: Colors.purple.shade400, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pending Verification',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(
                          '₹$pendingAmount locked pending reward unlock',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('In progress',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.red,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Refer & Earn banner ───────────────────────────────────────────────────

class _ReferBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _ReferBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.teal.shade100),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.share, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Refer & Earn',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.teal),
                  ),
                  Text(
                    'Invite friends — earn ₹100 when they pay first rent',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.teal),
          ],
        ),
      ),
    );
  }
}

// ── Transaction list ──────────────────────────────────────────────────────

class _TransactionList extends StatelessWidget {
  final String uid;
  const _TransactionList({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: HostelService().watchUserTransactions(uid),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('No transactions yet.',
                      style: TextStyle(color: Colors.black45)),
                ),
              )
            else
              ...docs.map((doc) => _TransactionTile(data: doc.data())),
          ],
        );
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TransactionTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? '';
    final amount = (data['amount'] as num?)?.toInt() ?? 0;
    final description = data['description'] as String? ?? '';
    final status = data['status'] as String? ?? 'completed';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    final isDebit = amount < 0;
    final icon = _iconForType(type);
    final iconBg = _bgForType(type, isDebit);
    final iconColor = _colorForType(type, isDebit);
    final title = _titleForType(type);
    final statusColor = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description.isNotEmpty)
              Text(description,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.black54)),
            if (createdAt != null)
              Text(
                _formatDate(createdAt),
                style: const TextStyle(fontSize: 11, color: Colors.black38),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isDebit ? '' : '+'}₹${amount.abs()}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isDebit ? Colors.red : const Color(0xFF0060AD),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status[0].toUpperCase() + status.substring(1),
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _titleForType(String type) {
    switch (type) {
      case 'referral_reward':
        return 'Referral Reward';
      case 'ad_earning':
        return 'Ad Earning';
      case 'cashback':
        return 'Service Cashback';
      case 'reversal':
        return 'Reversal';
      case 'withdrawal':
        return 'Withdrawal';
      default:
        return 'Transaction';
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'referral_reward':
        return Icons.share;
      case 'ad_earning':
        return Icons.visibility_outlined;
      case 'cashback':
        return Icons.card_membership_outlined;
      case 'reversal':
        return Icons.history;
      case 'withdrawal':
        return Icons.payments_outlined;
      default:
        return Icons.swap_horiz;
    }
  }

  Color _bgForType(String type, bool isDebit) {
    if (type == 'reversal' || isDebit) return Colors.red.shade50;
    if (type == 'cashback') return Colors.purple.shade50;
    if (type == 'ad_earning') return Colors.blue.shade50;
    return Colors.teal.shade50;
  }

  Color _colorForType(String type, bool isDebit) {
    if (type == 'reversal' || isDebit) return Colors.red;
    if (type == 'cashback') return Colors.purple;
    if (type == 'ad_earning') return Colors.blue;
    return Colors.teal;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'reversed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      final h = d.hour.toString().padLeft(2, '0');
      final m = d.minute.toString().padLeft(2, '0');
      return 'Today, $h:$m';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day) {
      return 'Yesterday';
    }
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month]}';
  }
}

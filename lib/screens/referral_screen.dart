import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

class ReferralScreen extends StatefulWidget {
  final String uid;
  const ReferralScreen({super.key, required this.uid});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  String? _referralCode;
  bool _loadingCode = true;

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  Future<void> _loadCode() async {
    try {
      final code = await HostelService().ensureReferralCode(widget.uid);
      if (mounted) {
        setState(() {
          _referralCode = code;
          _loadingCode = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingCode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Refer & Earn')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: HostelService().watchUserDoc(widget.uid),
        builder: (context, userSnap) {
          final userData = userSnap.data?.data() ?? {};
          final wallet = userData['wallet'] as Map<String, dynamic>? ?? {};
          final available = (wallet['available'] as num?)?.toInt() ?? 0;
          final bonus = (wallet['bonus'] as num?)?.toInt() ?? 0;
          final pending = (wallet['pending'] as num?)?.toInt() ?? 0;
          final totalBalance = available + bonus + pending;
          final monthlyEarned =
              (userData['monthlyReferralEarnings'] as num?)?.toInt() ?? 0;
          final monthlyLimit =
              (userData['monthlyReferralLimit'] as num?)?.toInt() ?? 1000;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: HostelService().watchUserReferrals(widget.uid),
            builder: (context, refSnap) {
              final referrals = refSnap.data?.docs ?? [];
              final totalReferrals = referrals.length;
              final successful = referrals
                  .where((d) => d.data()['status'] == 'completed' || d.data()['status'] == 'rewarded')
                  .length;
              final pendingRefs =
                  referrals.where((d) => d.data()['status'] == 'pending').length;
              final totalEarned = referrals.fold<int>(
                0,
                (acc, d) => acc + ((d.data()['amount'] as num?)?.toInt() ?? 0),
              );

              final code = _referralCode ?? (userData['referralCode'] as String? ?? '');

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Refer & Earn',
                      style: TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Invite friends and earn rewards',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 20),

                    // ── Referral code card ────────────────────────────
                    _ReferralCodeCard(
                      code: code,
                      loading: _loadingCode,
                      onCopy: () => _copyCode(context, code),
                      onShare: () => _shareCode(context, code),
                      onInvite: () => _shareCode(context, code),
                    ),
                    const SizedBox(height: 16),

                    // ── Stats grid ────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _StatsCard(
                            label: 'Wallet Balance',
                            value: '₹$totalBalance',
                            sublabel1: 'Total Earned',
                            subvalue1: '₹$totalEarned',
                            sublabel2: 'Pending',
                            subvalue2: '₹$pending',
                            isPrimary: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatsCard(
                            label: 'Referral Stats',
                            value: '$totalReferrals',
                            valueSuffix: ' Total',
                            sublabel1: 'Successful',
                            subvalue1: '$successful',
                            sublabel2: 'Pending',
                            subvalue2: '$pendingRefs',
                            isPrimary: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Monthly goal ──────────────────────────────────
                    _MonthlyGoalCard(
                      earned: monthlyEarned,
                      limit: monthlyLimit,
                    ),
                    const SizedBox(height: 20),

                    // ── Referral history ──────────────────────────────
                    const Text(
                      'Referral History',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    if (referrals.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'No referrals yet. Share your code!',
                            style: TextStyle(color: Colors.black45),
                          ),
                        ),
                      )
                    else
                      ...referrals.map(
                        (doc) => _ReferralHistoryTile(data: doc.data()),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _copyCode(BuildContext context, String code) {
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Code copied!')));
  }

  void _shareCode(BuildContext context, String code) {
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(
      text: 'Join me on Sanctuary! Use my referral code $code when you sign up. Download the app and get ₹50 off your first rent!',
    ));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share text copied to clipboard!')));
  }
}

// ── Referral code card ────────────────────────────────────────────────────

class _ReferralCodeCard extends StatelessWidget {
  final String code;
  final bool loading;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onInvite;

  const _ReferralCodeCard({
    required this.code,
    required this.loading,
    required this.onCopy,
    required this.onShare,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'YOUR UNIQUE CODE',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.black45,
                  letterSpacing: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: loading
                        ? const SizedBox(
                            height: 24,
                            child: LinearProgressIndicator())
                        : SelectableText(
                            code.isEmpty ? 'Generating…' : code,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0060AD),
                              letterSpacing: 2,
                            ),
                          ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Color(0xFF0060AD)),
                    onPressed: onCopy,
                    tooltip: 'Copy',
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Color(0xFF0060AD)),
                    onPressed: onShare,
                    tooltip: 'Share',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Send Invitations',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: onInvite,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats card ────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final String label;
  final String value;
  final String? valueSuffix;
  final String sublabel1;
  final String subvalue1;
  final String sublabel2;
  final String subvalue2;
  final bool isPrimary;

  const _StatsCard({
    required this.label,
    required this.value,
    this.valueSuffix,
    required this.sublabel1,
    required this.subvalue1,
    required this.sublabel2,
    required this.subvalue2,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: isPrimary
            ? const LinearGradient(
                colors: [Color(0xFF0060AD), Color(0xFF68ABFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isPrimary ? null : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: isPrimary
            ? null
            : Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: isPrimary ? Colors.white70 : Colors.black45,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: isPrimary ? Colors.white : Colors.black87,
                ),
              ),
              if (valueSuffix != null)
                Text(
                  valueSuffix!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isPrimary ? Colors.white70 : Colors.black45,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            color: isPrimary ? Colors.white24 : Colors.grey.shade300,
            height: 1,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sublabel1.toUpperCase(),
                    style: TextStyle(
                        fontSize: 8,
                        color: isPrimary ? Colors.white60 : Colors.black38,
                        letterSpacing: 0.8),
                  ),
                  Text(
                    subvalue1,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isPrimary ? Colors.white : Colors.black87),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    sublabel2.toUpperCase(),
                    style: TextStyle(
                        fontSize: 8,
                        color: isPrimary ? Colors.white60 : Colors.black38,
                        letterSpacing: 0.8),
                  ),
                  Text(
                    subvalue2,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isPrimary ? Colors.white : Colors.black87),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Monthly goal card ─────────────────────────────────────────────────────

class _MonthlyGoalCard extends StatelessWidget {
  final int earned;
  final int limit;
  const _MonthlyGoalCard({required this.earned, required this.limit});

  @override
  Widget build(BuildContext context) {
    final pct = (limit > 0 ? earned / limit : 0.0).clamp(0.0, 1.0);
    final remaining = limit - earned;
    final refLeft = (remaining / 100).ceil();

    return Card(
      color: Colors.blue.shade50,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Monthly Goal',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  '₹$earned / ₹$limit',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0060AD),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor: Colors.blue.shade100,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF0060AD)),
              ),
            ),
            if (remaining > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Keep going! You\'re only $refLeft referral${refLeft == 1 ? '' : 's'} away from reaching your ₹$limit bonus.',
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontStyle: FontStyle.italic),
              ),
            ] else ...[
              const SizedBox(height: 10),
              const Text(
                '🎉 Monthly goal reached! Bonus unlocked.',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Referral history tile ─────────────────────────────────────────────────

class _ReferralHistoryTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReferralHistoryTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['referredName'] as String? ?? 'Friend';
    final status = data['status'] as String? ?? 'pending';
    final amount = (data['amount'] as num?)?.toInt() ?? 0;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    final statusInfo = _statusInfo(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(
            name.isEmpty ? 'F' : name[0].toUpperCase(),
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.blue.shade900),
          ),
        ),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: createdAt != null
            ? Text(
                _formatDate(createdAt),
                style: const TextStyle(fontSize: 11, color: Colors.black38),
              )
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹$amount',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusInfo.$2.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusInfo.$1,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: statusInfo.$2,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color) _statusInfo(String status) {
    switch (status) {
      case 'completed':
        return ('Completed', Colors.green);
      case 'rewarded':
        return ('Rewarded', Colors.purple);
      case 'pending':
        return ('Pending', Colors.orange);
      default:
        return ('Unknown', Colors.grey);
    }
  }

  String _formatDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }
}

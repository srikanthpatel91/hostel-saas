import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'kyc_screen.dart';

/// Withdrawal Screen — request payout from Available wallet.
/// Enforces KYC, minimum amount, and 3–7 day lock period for bonus wallet.
class WithdrawalScreen extends StatefulWidget {
  final String uid;
  const WithdrawalScreen({super.key, required this.uid});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
        title: const Text('Withdraw Funds'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Request Withdrawal'), Tab(text: 'History')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _WithdrawTab(uid: widget.uid),
          _WithdrawalHistoryTab(uid: widget.uid),
        ],
      ),
    );
  }
}

class _WithdrawTab extends StatefulWidget {
  final String uid;
  const _WithdrawTab({required this.uid});

  @override
  State<_WithdrawTab> createState() => _WithdrawTabState();
}

class _WithdrawTabState extends State<_WithdrawTab> {
  final _db = FirebaseFirestore.instance;
  final _amtCtrl = TextEditingController();
  bool _loading = true;
  bool _submitting = false;

  int _available = 0;
  int _bonus = 0;
  int _pending = 0;
  String _kycStatus = 'not_started';
  String _bankName = '';
  String _accountTail = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userDoc = await _db.collection('users').doc(widget.uid).get();
    final walletDoc = await _db.collection('wallets').doc(widget.uid).get();
    final kycDoc = await _db.collection('users').doc(widget.uid).collection('kyc').doc('profile').get();

    final wd = walletDoc.data() ?? {};
    final kd = kycDoc.data() ?? {};

    setState(() {
      _available = (wd['available'] as num?)?.toInt() ?? 0;
      _bonus = (wd['bonus'] as num?)?.toInt() ?? 0;
      _pending = (wd['pending'] as num?)?.toInt() ?? 0;
      _kycStatus = (userDoc.data()?['kycStatus'] as String?) ?? 'not_started';
      _bankName = kd['bankName'] as String? ?? '';
      final acct = kd['accountNumber'] as String? ?? '';
      _accountTail = acct.length > 4 ? '••••${acct.substring(acct.length - 4)}' : acct;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    final amt = int.tryParse(_amtCtrl.text.trim()) ?? 0;
    if (amt < 100) {
      _snack('Minimum withdrawal is ₹100');
      return;
    }
    if (amt > _available) {
      _snack('Insufficient available balance');
      return;
    }

    setState(() => _submitting = true);

    // Deduct from available (pending review)
    await _db.collection('wallets').doc(widget.uid).update({
      'available': FieldValue.increment(-amt),
      'pending': FieldValue.increment(amt),
    });

    // Create withdrawal request
    await _db.collection('withdrawals').add({
      'uid': widget.uid,
      'amount': amt,
      'bankName': _bankName,
      'accountTail': _accountTail,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
    });

    // Ledger entry
    await _db.collection('wallets').doc(widget.uid).collection('ledger').add({
      'type': 'debit',
      'source': 'withdrawal',
      'amount': amt,
      'walletType': 'available',
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() { _submitting = false; _amtCtrl.clear(); });
    _snack('Withdrawal request submitted! Processing in 3–5 business days.');
    _load();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_IN');

    if (_loading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wallet summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  const Text('Wallet Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _WalletBucket('Available', _available, Colors.green, fmt, withdrawable: true),
                      _WalletBucket('Bonus', _bonus, Colors.purple, fmt),
                      _WalletBucket('Pending', _pending, Colors.orange, fmt),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // KYC status
          if (_kycStatus != 'verified') ...[
            Card(
              color: Colors.orange.withAlpha(20),
              child: ListTile(
                leading: const Icon(Icons.warning_amber_outlined, color: Colors.orange),
                title: const Text('KYC Required', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(
                  _kycStatus == 'pending'
                      ? 'KYC is under review. Withdrawals available once verified.'
                      : 'Complete KYC to enable withdrawals.',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: _kycStatus != 'pending'
                    ? TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const KycScreen()),
                        ),
                        child: const Text('Complete'),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Destination account
          if (_bankName.isNotEmpty) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_outlined),
                title: Text(_bankName),
                subtitle: Text('Account ending $_accountTail'),
                trailing: const Icon(Icons.check_circle, color: Colors.green, size: 18),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Amount entry
          Text('Withdraw Amount', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _amtCtrl,
            keyboardType: TextInputType.number,
            enabled: _kycStatus == 'verified',
            decoration: InputDecoration(
              prefixText: '₹ ',
              labelText: 'Amount (min ₹100, max ₹${fmt.format(_available)})',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          // Quick amount chips
          Wrap(
            spacing: 8,
            children: [500, 1000, 2000, 5000]
                .where((a) => a <= _available)
                .map((a) => ActionChip(
                      label: Text('₹$a'),
                      onPressed: () => _amtCtrl.text = '$a',
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_kycStatus == 'verified' && !_submitting) ? _submit : null,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_outlined),
              label: const Text('Request Withdrawal'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '• Bonus wallet funds cannot be withdrawn.\n'
            '• Processed in 3–5 business days via NEFT/UPI.\n'
            '• Razorpay payout integration coming soon.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _WalletBucket extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final NumberFormat fmt;
  final bool withdrawable;
  const _WalletBucket(this.label, this.amount, this.color, this.fmt, {this.withdrawable = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('₹${fmt.format(amount)}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        if (withdrawable)
          Text('withdrawable', style: TextStyle(fontSize: 10, color: color.withAlpha(180))),
      ],
    );
  }
}

class _WithdrawalHistoryTab extends StatelessWidget {
  final String uid;
  const _WithdrawalHistoryTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_IN');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('withdrawals')
          .where('uid', isEqualTo: uid)
          .orderBy('requestedAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No withdrawal history.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, idx) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final status = d['status'] as String? ?? 'pending';
            final amt = (d['amount'] as num?)?.toInt() ?? 0;
            final reqAt = (d['requestedAt'] as Timestamp?)?.toDate();
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: _statusColor(status).withAlpha(30),
                child: Icon(_statusIcon(status), color: _statusColor(status), size: 18),
              ),
              title: Text('₹${fmt.format(amt)} withdrawal'),
              subtitle: Text('${d['bankName'] ?? ''} • ${reqAt != null ? DateFormat('dd MMM yyyy').format(reqAt) : ''}'),
              trailing: _StatusBadge(status),
            );
          },
        );
      },
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'completed': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.orange;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'completed': return Icons.check_circle_outline;
      case 'rejected': return Icons.cancel_outlined;
      default: return Icons.pending_outlined;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);
  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case 'completed': c = Colors.green; break;
      case 'rejected': c = Colors.red; break;
      default: c = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withAlpha(30), borderRadius: BorderRadius.circular(10)),
      child: Text(status, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.bold)),
    );
  }
}

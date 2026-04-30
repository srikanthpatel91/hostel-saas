import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

class DepositTrackingScreen extends StatelessWidget {
  final String hostelId;
  const DepositTrackingScreen({super.key, required this.hostelId});

  Future<void> _editDeposit(
    BuildContext context,
    String guestId,
    String guestName,
    int depositAmount,
    String currentStatus,
    int currentPaid,
  ) async {
    String status = currentStatus;
    final paidCtrl = TextEditingController(text: currentPaid.toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Deposit — $guestName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Required: ₹$depositAmount',
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),
              TextFormField(
                controller: paidCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount received (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Status:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'pending', label: Text('Pending')),
                  ButtonSegment(value: 'partial', label: Text('Partial')),
                  ButtonSegment(value: 'paid', label: Text('Paid')),
                  ButtonSegment(value: 'refunded', label: Text('Refunded')),
                ],
                selected: {status},
                onSelectionChanged: (v) => setS(() => status = v.first),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Update')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    try {
      await HostelService().updateDepositStatus(
        hostelId: hostelId,
        guestId: guestId,
        depositStatus: status,
        depositPaid: int.tryParse(paidCtrl.text.trim()) ?? currentPaid,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Deposit updated'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Color _statusColor(String status) => switch (status) {
        'paid' => Colors.green,
        'partial' => Colors.orange,
        'refunded' => Colors.blue,
        _ => Colors.red,
      };

  String _statusLabel(String status) => switch (status) {
        'paid' => 'Paid',
        'partial' => 'Partial',
        'refunded' => 'Refunded',
        _ => 'Pending',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security Deposits')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('hostels')
            .doc(hostelId)
            .collection('guests')
            .orderBy('joinedAt', descending: false)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          final active = docs.where((d) => d.data()['isActive'] == true).toList();

          if (active.isEmpty) {
            return const Center(child: Text('No active tenants'));
          }

          // Summary
          int totalRequired = 0, totalCollected = 0, totalPending = 0;
          for (final d in active) {
            final data = d.data();
            final required = (data['depositAmount'] as num?)?.toInt() ?? 0;
            final paid = (data['depositPaid'] as num?)?.toInt() ?? 0;
            final status = data['depositStatus'] as String? ?? 'paid';
            totalRequired += required;
            if (status == 'paid') {
              totalCollected += required;
            } else if (status == 'partial') {
              totalCollected += paid;
              totalPending += required - paid;
            } else if (status == 'pending') {
              totalPending += required;
            }
          }

          return Column(
            children: [
              // Summary banner
              Container(
                color: Colors.purple.shade50,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _DepositStat(
                          label: 'Required', amount: totalRequired, color: Colors.purple),
                    ),
                    Expanded(
                      child: _DepositStat(
                          label: 'Collected', amount: totalCollected, color: Colors.green),
                    ),
                    Expanded(
                      child: _DepositStat(
                          label: 'Pending', amount: totalPending, color: Colors.red),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: active.length,
                  itemBuilder: (ctx, i) {
                    final data = active[i].data();
                    final name = data['name'] as String? ?? '';
                    final room = data['roomNumber'] as String? ?? '';
                    final required = (data['depositAmount'] as num?)?.toInt() ?? 0;
                    final paid = (data['depositPaid'] as num?)?.toInt() ??
                        (data['depositStatus'] == 'paid' ? required : 0);
                    final status = data['depositStatus'] as String? ?? 'paid';
                    final color = _statusColor(status);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
                        ),
                        title: Text(name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Room $room'),
                            if (status == 'partial')
                              Text('Received ₹$paid of ₹$required',
                                  style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹$required',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(_statusLabel(status),
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: color)),
                            ),
                          ],
                        ),
                        onTap: () => _editDeposit(
                            context, active[i].id, name, required, status, paid),
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

class _DepositStat extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  const _DepositStat(
      {required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: color)),
        const SizedBox(height: 2),
        Text('₹$amount',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16, color: color)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

class CheckoutRequestsScreen extends StatelessWidget {
  final String hostelId;
  const CheckoutRequestsScreen({super.key, required this.hostelId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout Requests')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: HostelService().watchCheckoutRequests(hostelId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          // Sort by createdAt descending in-app
          final sorted = List.of(docs)
            ..sort((a, b) {
              final ta = (a.data()['createdAt'] as Timestamp?)
                      ?.millisecondsSinceEpoch ??
                  0;
              final tb = (b.data()['createdAt'] as Timestamp?)
                      ?.millisecondsSinceEpoch ??
                  0;
              return tb.compareTo(ta);
            });

          if (sorted.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.exit_to_app, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No pending checkout requests',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sorted.length,
            itemBuilder: (ctx, i) {
              final doc = sorted[i];
              final data = doc.data();
              final requestId = doc.id;
              final guestId = data['guestId'] as String? ?? '';
              final guestName = data['guestName'] as String? ?? '';
              final roomNumber = data['roomNumber'] as String? ?? '';
              final note = data['note'] as String? ?? '';
              final moveOut =
                  (data['expectedMoveOut'] as Timestamp?)?.toDate();
              final createdAt =
                  (data['createdAt'] as Timestamp?)?.toDate();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.orange.shade100,
                            child: Text(
                              guestName.isEmpty
                                  ? '?'
                                  : guestName[0].toUpperCase(),
                              style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(guestName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                                Text('Room $roomNumber',
                                    style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                          if (createdAt != null)
                            Text(
                              _fmtDate(createdAt),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black45),
                            ),
                        ],
                      ),
                      if (moveOut != null) ...[
                        const SizedBox(height: 10),
                        _InfoChip(
                          icon: Icons.calendar_today_outlined,
                          label:
                              'Expected move-out: ${_fmtDate(moveOut)}',
                        ),
                      ],
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _InfoChip(
                          icon: Icons.notes_outlined,
                          label: note,
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Deny'),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red),
                              onPressed: () => _deny(
                                  context, requestId, guestName),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Approve checkout'),
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.teal),
                              onPressed: () => _approve(
                                  context, requestId, guestId, guestName),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const m = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  Future<void> _approve(BuildContext context, String requestId,
      String guestId, String guestName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve checkout?'),
        content: Text(
            'This will check out $guestName and free their bed. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Approve')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await HostelService().approveCheckout(
        hostelId: hostelId,
        requestId: requestId,
        guestId: guestId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$guestName checked out successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deny(
      BuildContext context, String requestId, String guestName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deny checkout?'),
        content: Text('$guestName\'s checkout request will be denied.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Deny',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    await HostelService()
        .denyCheckout(hostelId: hostelId, requestId: requestId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$guestName\'s request denied')),
      );
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.black45),
        const SizedBox(width: 4),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
        ),
      ],
    );
  }
}

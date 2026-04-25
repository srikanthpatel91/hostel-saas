import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

class GuestDetailScreen extends StatelessWidget {
  final String hostelId;
  final String guestId;

  const GuestDetailScreen({
    super.key,
    required this.hostelId,
    required this.guestId,
  });

  Future<void> _confirmExit(BuildContext context, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as exited?'),
        content: Text(
          '$name will be moved to the Exited list. Their bed will become vacant again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark exited'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await HostelService().markGuestExited(
        hostelId: hostelId,
        guestId: guestId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guest marked as exited'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guest details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: HostelService().watchGuest(
          hostelId: hostelId,
          guestId: guestId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Guest not found'));
          }

          final data = snapshot.data!.data()!;
          final name = data['name'] as String? ?? '';
          final phone = data['phone'] as String? ?? '';
          final roomNumber = data['roomNumber'] as String? ?? '';
          final isActive = data['isActive'] == true;
          final rent = (data['rentAmount'] as num?)?.toInt() ?? 0;
          final deposit = (data['depositAmount'] as num?)?.toInt() ?? 0;
          final joinedAt = (data['joinedAt'] as Timestamp?)?.toDate();
          final exitedAt = (data['exitedAt'] as Timestamp?)?.toDate();
          final notes = data['notes'] as String? ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: isActive
                              ? Colors.teal.shade100
                              : Colors.grey.shade300,
                          child: Text(
                            name.isEmpty ? '?' : name[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? Colors.teal.shade900
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(phone,
                                  style: TextStyle(
                                      color: Colors.grey.shade700)),
                              if (!isActive) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Exited',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Stay info
                Card(
                  child: Column(
                    children: [
                      _InfoRow(label: 'Room', value: 'Room $roomNumber'),
                      _InfoRow(
                          label: 'Joined',
                          value: joinedAt != null
                              ? _formatDate(joinedAt)
                              : '-'),
                      if (exitedAt != null)
                        _InfoRow(
                            label: 'Exited', value: _formatDate(exitedAt)),
                      _InfoRow(
                          label: 'Monthly rent', value: '₹$rent'),
                      _InfoRow(
                          label: 'Security deposit',
                          value: '₹$deposit',
                          isLast: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (notes.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notes',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(notes),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Mark exited button — only if active
                if (isActive)
                  FilledButton.icon(
                    onPressed: () => _confirmExit(context, name),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Mark as exited'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

class ComplaintsOwnerScreen extends StatefulWidget {
  final String hostelId;
  const ComplaintsOwnerScreen({super.key, required this.hostelId});

  @override
  State<ComplaintsOwnerScreen> createState() => _ComplaintsOwnerScreenState();
}

class _ComplaintsOwnerScreenState extends State<ComplaintsOwnerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(
      BuildContext context, String complaintId, String currentStatus) async {
    String status = currentStatus;
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Update complaint'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Status:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'open', label: Text('Open')),
                  ButtonSegment(
                      value: 'in_progress', label: Text('In Progress')),
                  ButtonSegment(value: 'resolved', label: Text('Resolved')),
                ],
                selected: {status},
                onSelectionChanged: (v) => setS(() => status = v.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'E.g. "Plumber scheduled for tomorrow"',
                ),
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
      await HostelService().updateComplaintStatus(
        hostelId: widget.hostelId,
        complaintId: complaintId,
        status: status,
        ownerNotes: notesCtrl.text.trim(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Complaint updated'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Open'),
            Tab(text: 'In Progress'),
            Tab(text: 'Resolved'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: HostelService().watchComplaints(widget.hostelId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data?.docs ?? [];

          return TabBarView(
            controller: _tabs,
            children: [
              _ComplaintList(
                docs: all.where((d) => d.data()['status'] == 'open').toList(),
                onUpdate: _updateStatus,
                emptyLabel: 'No open complaints',
              ),
              _ComplaintList(
                docs: all
                    .where((d) => d.data()['status'] == 'in_progress')
                    .toList(),
                onUpdate: _updateStatus,
                emptyLabel: 'Nothing in progress',
              ),
              _ComplaintList(
                docs: all
                    .where((d) => d.data()['status'] == 'resolved')
                    .toList(),
                onUpdate: _updateStatus,
                emptyLabel: 'No resolved complaints yet',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ComplaintList extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final Future<void> Function(BuildContext, String, String) onUpdate;
  final String emptyLabel;

  const _ComplaintList({
    required this.docs,
    required this.onUpdate,
    required this.emptyLabel,
  });

  Color _statusColor(String s) => switch (s) {
        'resolved' => Colors.green,
        'in_progress' => Colors.blue,
        _ => Colors.orange,
      };

  String _statusLabel(String s) => switch (s) {
        'resolved' => 'Resolved',
        'in_progress' => 'In Progress',
        _ => 'Open',
      };

  IconData _catIcon(String cat) => switch (cat) {
        'Maintenance' => Icons.build,
        'Cleanliness' => Icons.cleaning_services,
        'Noise' => Icons.volume_up,
        'Water' => Icons.water_drop,
        'Electricity' => Icons.bolt,
        'Internet' => Icons.wifi_off,
        'Security' => Icons.security,
        _ => Icons.report_problem,
      };

  String _fmtDate(DateTime d) {
    const m = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${m[d.month]}';
  }

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(emptyLabel,
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: docs.length,
      itemBuilder: (ctx, i) {
        final data = docs[i].data();
        final guestName = data['guestName'] as String? ?? '';
        final roomNumber = data['roomNumber'] as String? ?? '';
        final category = data['category'] as String? ?? '';
        final description = data['description'] as String? ?? '';
        final status = data['status'] as String? ?? 'open';
        final ownerNotes = data['ownerNotes'] as String? ?? '';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final statusColor = _statusColor(status);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.15),
              child: Icon(_catIcon(category),
                  color: statusColor, size: 20),
            ),
            title: Text(
              '$guestName — $category',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Room $roomNumber${createdAt != null ? '  •  ${_fmtDate(createdAt)}' : ''}',
            ),
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusLabel(status),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor),
              ),
            ),
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(description,
                        style: const TextStyle(fontSize: 14)),
                    if (ownerNotes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.comment_outlined,
                                size: 16, color: Colors.blue),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(ownerNotes,
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.blue)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Update status'),
                      onPressed: () =>
                          onUpdate(ctx, docs[i].id, status),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

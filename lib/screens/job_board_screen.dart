import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Job Board — hostel owners post job openings,
/// users (prospective staff) can browse and apply.
class JobBoardScreen extends StatefulWidget {
  final String? hostelId; // if set, owner mode (can post jobs)
  const JobBoardScreen({super.key, this.hostelId});

  @override
  State<JobBoardScreen> createState() => _JobBoardScreenState();
}

class _JobBoardScreenState extends State<JobBoardScreen> {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _isOwner => widget.hostelId != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Board'),
        centerTitle: true,
      ),
      floatingActionButton: _isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _showPostJobSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Post Job'),
            )
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _isOwner
            ? _db
                .collection('jobs')
                .where('hostelId', isEqualTo: widget.hostelId)
                .orderBy('createdAt', descending: true)
                .snapshots()
            : _db
                .collection('jobs')
                .where('status', isEqualTo: 'open')
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.work_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    _isOwner ? 'No jobs posted yet' : 'No open positions',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  if (_isOwner) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => _showPostJobSheet(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Post First Job'),
                    ),
                  ],
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, idx) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _JobCard(
              doc: docs[i],
              isOwner: _isOwner,
              uid: _uid,
            ),
          );
        },
      ),
    );
  }

  void _showPostJobSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PostJobSheet(hostelId: widget.hostelId!),
    );
  }
}

class _JobCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool isOwner;
  final String uid;
  const _JobCard({required this.doc, required this.isOwner, required this.uid});

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  bool _applying = false;

  Future<void> _apply() async {
    setState(() => _applying = true);
    await FirebaseFirestore.instance
        .collection('jobs').doc(widget.doc.id)
        .collection('applications')
        .doc(widget.uid)
        .set({
      'uid': widget.uid,
      'appliedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    if (mounted) {
      setState(() => _applying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application submitted!')),
      );
    }
  }

  Future<void> _closeJob() async {
    await widget.doc.reference.update({'status': 'closed'});
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc.data();
    final title = d['title'] as String? ?? '';
    final role = d['role'] as String? ?? '';
    final salary = d['salary'] as String? ?? '';
    final location = d['location'] as String? ?? '';
    final description = d['description'] as String? ?? '';
    final status = d['status'] as String? ?? 'open';
    final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
    final hostelName = d['hostelName'] as String? ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(
                        hostelName.isNotEmpty ? hostelName : location,
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (role.isNotEmpty) _Tag(role, Colors.blue),
                if (salary.isNotEmpty) _Tag(salary, Colors.green),
                if (createdAt != null)
                  _Tag(DateFormat('dd MMM').format(createdAt), Colors.grey),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(description, style: const TextStyle(fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 10),
            if (!widget.isOwner && status == 'open')
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _applying ? null : _apply,
                  icon: _applying
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_outlined, size: 16),
                  label: const Text('Apply Now'),
                ),
              ),
            if (widget.isOwner)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ApplicationCount(jobId: widget.doc.id),
                  if (status == 'open')
                    TextButton.icon(
                      onPressed: _closeJob,
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      label: const Text('Close', style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationCount extends StatelessWidget {
  final String jobId;
  const _ApplicationCount({required this.jobId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs').doc(jobId)
          .collection('applications')
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Text('$count applicant${count == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 12, color: Colors.grey));
      },
    );
  }
}

class _PostJobSheet extends StatefulWidget {
  final String hostelId;
  const _PostJobSheet({required this.hostelId});

  @override
  State<_PostJobSheet> createState() => _PostJobSheetState();
}

class _PostJobSheetState extends State<_PostJobSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  String _role = 'staff';
  bool _saving = false;

  static const _roles = ['manager', 'warden', 'chef', 'cleaning_head', 'security', 'staff', 'other'];

  Future<void> _post() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    // Get hostel name
    final hostelDoc = await FirebaseFirestore.instance
        .collection('hostels').doc(widget.hostelId).get();
    final hostelName = hostelDoc.data()?['name'] ?? '';

    await FirebaseFirestore.instance.collection('jobs').add({
      'hostelId': widget.hostelId,
      'hostelName': hostelName,
      'title': _titleCtrl.text.trim(),
      'role': _role,
      'description': _descCtrl.text.trim(),
      'salary': _salaryCtrl.text.trim(),
      'location': hostelDoc.data()?['city'] ?? '',
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Post a Job', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Job Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
            items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r.replaceAll('_', ' ').capitalize()))).toList(),
            onChanged: (v) => setState(() => _role = v!),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _salaryCtrl,
            decoration: const InputDecoration(labelText: 'Salary (e.g. ₹12,000/month)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _post,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Post Job'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);
  @override
  Widget build(BuildContext context) {
    final isOpen = status == 'open';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isOpen ? Colors.green : Colors.grey).withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isOpen ? 'Open' : 'Closed',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isOpen ? Colors.green : Colors.grey,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag(this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

extension _StrExt on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

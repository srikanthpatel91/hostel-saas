import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

class NoticeBoardScreen extends StatelessWidget {
  final String hostelId;
  const NoticeBoardScreen({super.key, required this.hostelId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notice Board')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Post a notice',
        child: const Icon(Icons.add),
        onPressed: () => _showAddNotice(context),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: HostelService().watchNotices(hostelId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No notices yet',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('Tap + to broadcast a message to all tenants',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data();
              final id = docs[i].id;
              final title = data['title'] as String? ?? '';
              final body = data['body'] as String? ?? '';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final audience = data['targetAudience'] as String? ?? 'all';

              return Dismissible(
                key: Key(id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.delete_outline,
                      color: Colors.red.shade700, size: 24),
                ),
                confirmDismiss: (_) => showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete notice?'),
                    content: const Text(
                        'Recipients will no longer see this notice.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
                onDismissed: (_) => HostelService()
                    .deleteNotice(hostelId: hostelId, noticeId: id),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.campaign,
                                size: 18, color: Colors.teal.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                            ),
                            if (createdAt != null)
                              Text(
                                _fmtDate(createdAt),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black45),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _AudienceBadge(audience: audience),
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(body,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black87,
                                  height: 1.4)),
                        ],
                      ],
                    ),
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
    return '${d.day} ${m[d.month]}';
  }

  void _showAddNotice(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _AddNoticeSheet(hostelId: hostelId),
    );
  }
}

// audience options: value → display label
const _kAudiences = {
  'all': 'All',
  'tenants': 'Tenants',
  'manager': 'Manager',
  'warden': 'Warden',
  'staff': 'Staff',
  'chef': 'Chef',
  'cleaning': 'Cleaning',
};

class _AudienceBadge extends StatelessWidget {
  final String audience;
  const _AudienceBadge({required this.audience});

  @override
  Widget build(BuildContext context) {
    final label = _kAudiences[audience] ?? audience;
    final color = audience == 'all' ? Colors.teal : Colors.deepPurple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        'For: $label',
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _AddNoticeSheet extends StatefulWidget {
  final String hostelId;
  const _AddNoticeSheet({required this.hostelId});

  @override
  State<_AddNoticeSheet> createState() => _AddNoticeSheetState();
}

class _AddNoticeSheetState extends State<_AddNoticeSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _audience = 'all';
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await HostelService().addNotice(
        hostelId: widget.hostelId,
        title: _titleCtrl.text,
        body: _bodyCtrl.text,
        targetAudience: _audience,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign, color: Colors.teal),
              const SizedBox(width: 8),
              const Text('Post a notice',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title *',
              border: OutlineInputBorder(),
              hintText: 'e.g. Water supply off on Sunday',
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyCtrl,
            decoration: const InputDecoration(
              labelText: 'Details (optional)',
              border: OutlineInputBorder(),
              hintText: 'Add more details...',
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          const Text('Audience',
              style:
                  TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _kAudiences.entries.map((e) {
              final selected = _audience == e.key;
              return FilterChip(
                label: Text(e.value,
                    style: TextStyle(
                        fontSize: 12,
                        color: selected ? Colors.white : null)),
                selected: selected,
                onSelected: (_) => setState(() => _audience = e.key),
                selectedColor: Colors.teal,
                checkmarkColor: Colors.white,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, size: 18),
            label: Text(_saving
                ? 'Posting...'
                : 'Post to ${_kAudiences[_audience] ?? _audience}'),
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}

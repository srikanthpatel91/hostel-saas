import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

class MaintenanceScreen extends StatefulWidget {
  final String hostelId;
  const MaintenanceScreen({super.key, required this.hostelId});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  String _statusFilter = 'All';
  String _dateFilter = 'All';

  static const _statuses = ['All', 'open', 'in_progress', 'completed'];
  static const _statusLabels = {
    'All': 'All',
    'open': 'Open',
    'in_progress': 'In Progress',
    'completed': 'Completed',
  };

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (_statusFilter != 'All') {
      docs = docs.where((d) => d['status'] == _statusFilter).toList();
    }
    if (_dateFilter != 'All') {
      final now = DateTime.now();
      final DateTime cutoff;
      if (_dateFilter == 'This Week') {
        cutoff = now.subtract(Duration(days: now.weekday - 1));
        // start of current week (Monday)
      } else {
        cutoff = DateTime(now.year, now.month, 1);
      }
      final cutoffTs = cutoff.millisecondsSinceEpoch;
      docs = docs.where((d) {
        final ts = d['reportedAt'] as Timestamp?;
        if (ts == null) return false;
        return ts.millisecondsSinceEpoch >= cutoffTs;
      }).toList();
    }
    return docs;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'All',
                    label: Text('All time')),
                ButtonSegment(
                    value: 'This Week',
                    icon: Icon(Icons.view_week_outlined, size: 16),
                    label: Text('This Week')),
                ButtonSegment(
                    value: 'This Month',
                    icon: Icon(Icons.calendar_month_outlined, size: 16),
                    label: Text('This Month')),
              ],
              selected: {_dateFilter},
              onSelectionChanged: (s) =>
                  setState(() => _dateFilter = s.first),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _FilterBar(
            selected: _statusFilter,
            statuses: _statuses,
            labels: _statusLabels,
            onChanged: (v) => setState(() => _statusFilter = v),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: HostelService()
                  .watchMaintenanceRequests(widget.hostelId),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = _applyFilters(snap.data?.docs ?? []);
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.build_circle_outlined,
                            size: 56,
                            color: cs.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'No requests for this filter',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) =>
                      _RequestCard(doc: docs[i], hostelId: widget.hostelId),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Log Request'),
        onPressed: () => _showAddSheet(context),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddRequestSheet(hostelId: widget.hostelId),
    );
  }
}

// ─── Filter Bar ──────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final String selected;
  final List<String> statuses;
  final Map<String, String> labels;
  final ValueChanged<String> onChanged;
  const _FilterBar(
      {required this.selected,
      required this.statuses,
      required this.labels,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: statuses.map((s) {
          final sel = s == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(labels[s]!),
              selected: sel,
              onSelected: (_) => onChanged(s),
              selectedColor: cs.primaryContainer,
              checkmarkColor: cs.onPrimaryContainer,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Request Card ─────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String hostelId;
  const _RequestCard({required this.doc, required this.hostelId});

  static const _priorityColors = {
    'low': Colors.green,
    'medium': Colors.orange,
    'high': Colors.red,
  };

  static const _statusColors = {
    'open': Colors.red,
    'in_progress': Colors.orange,
    'completed': Colors.green,
  };

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final cs = Theme.of(context).colorScheme;
    final status = data['status'] as String? ?? 'open';
    final priority = data['priority'] as String? ?? 'low';
    final ts = data['reportedAt'] as Timestamp?;
    final cost = (data['estimatedCost'] as num?)?.toDouble();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(data['title'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                _PriorityDot(priority: priority, colors: _priorityColors),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (v) => _handleMenu(context, v),
                  itemBuilder: (_) => [
                    if (status != 'open')
                      const PopupMenuItem(
                          value: 'open', child: Text('Mark Open')),
                    if (status != 'in_progress')
                      const PopupMenuItem(
                          value: 'in_progress',
                          child: Text('Mark In Progress')),
                    if (status != 'completed')
                      const PopupMenuItem(
                          value: 'completed',
                          child: Text('Mark Completed')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _Chip(
                  label: data['category'] ?? '',
                  bg: cs.surfaceContainerHighest,
                  fg: cs.onSurface,
                ),
                _Chip(
                  label: (data['status'] as String? ?? 'open')
                      .replaceAll('_', ' ')
                      .toUpperCase(),
                  bg: (_statusColors[status] ?? Colors.grey).withValues(alpha: 0.15),
                  fg: _statusColors[status] ?? Colors.grey,
                ),
                if ((data['roomNumber'] as String? ?? '').isNotEmpty)
                  _Chip(
                    label: 'Room ${data['roomNumber']}',
                    bg: cs.secondaryContainer,
                    fg: cs.onSecondaryContainer,
                  ),
              ],
            ),
            if ((data['description'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(data['description'],
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.7), fontSize: 13)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (ts != null)
                  Text(
                    _fmtDate(ts.toDate()),
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                const Spacer(),
                if (cost != null)
                  Text(
                    '₹${cost.toStringAsFixed(0)} est.',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.primary,
                        fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenu(BuildContext context, String value) async {
    if (value == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete request?'),
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
      );
      if (ok == true) {
        await HostelService()
            .deleteMaintenanceRequest(hostelId: hostelId, requestId: doc.id);
      }
    } else {
      await HostelService().updateMaintenanceRequest(
        hostelId: hostelId,
        requestId: doc.id,
        status: value,
      );
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';
  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];
}

class _PriorityDot extends StatelessWidget {
  final String priority;
  final Map<String, Color> colors;
  const _PriorityDot({required this.priority, required this.colors});

  @override
  Widget build(BuildContext context) {
    final color = colors[priority] ?? Colors.grey;
    return Tooltip(
      message: '${priority[0].toUpperCase()}${priority.substring(1)} priority',
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Chip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child:
          Text(label, style: TextStyle(fontSize: 11, color: fg)),
    );
  }
}

// ─── Add Request Sheet ────────────────────────────────────────────────────────

class _AddRequestSheet extends StatefulWidget {
  final String hostelId;
  const _AddRequestSheet({required this.hostelId});

  @override
  State<_AddRequestSheet> createState() => _AddRequestSheetState();
}

class _AddRequestSheetState extends State<_AddRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  String _category = HostelService.maintenanceCategories.first;
  String _priority = 'medium';
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _roomCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Log Maintenance Request',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Title *', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                    labelText: 'Category', border: OutlineInputBorder()),
                items: HostelService.maintenanceCategories
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              Text('Priority', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'low',
                      label: Text('Low'),
                      icon: Icon(Icons.arrow_downward, size: 14)),
                  ButtonSegment(
                      value: 'medium',
                      label: Text('Medium'),
                      icon: Icon(Icons.remove, size: 14)),
                  ButtonSegment(
                      value: 'high',
                      label: Text('High'),
                      icon: Icon(Icons.arrow_upward, size: 14)),
                ],
                selected: {_priority},
                onSelectionChanged: (s) =>
                    setState(() => _priority = s.first),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _roomCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Room (optional)',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Est. Cost ₹',
                          border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Log Request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final cost = int.tryParse(_costCtrl.text.trim());
      await HostelService().addMaintenanceRequest(
        hostelId: widget.hostelId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category,
        priority: _priority,
        roomNumber: _roomCtrl.text.trim().isEmpty ? null : _roomCtrl.text.trim(),
        estimatedCost: cost,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

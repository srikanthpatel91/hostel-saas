import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

class DailyMenuScreen extends StatefulWidget {
  final String hostelId;
  const DailyMenuScreen({super.key, required this.hostelId});

  @override
  State<DailyMenuScreen> createState() => _DailyMenuScreenState();
}

class _DailyMenuScreenState extends State<DailyMenuScreen> {
  DateTime _selectedDate = DateTime.now();

  String get _dateKey => HostelService.menuDateKey(_selectedDate);

  String _fmtDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime(d.year, d.month, d.day);
    if (sel == today) return 'Today';
    if (sel == today.add(const Duration(days: 1))) return 'Tomorrow';
    if (sel == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  void _prevDay() =>
      setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));

  void _nextDay() =>
      setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Food Menu')),
      body: Column(
        children: [
          // Date navigation bar
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                    icon: const Icon(Icons.chevron_left), onPressed: _prevDay),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Column(
                      children: [
                        Text(
                          _fmtDate(_selectedDate),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        Text(
                          _dateKey,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.chevron_right), onPressed: _nextDay),
              ],
            ),
          ),
          // Menu form — reloads whenever date changes
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              key: ValueKey(_dateKey),
              stream: HostelService().watchDailyMenu(
                  hostelId: widget.hostelId, dateKey: _dateKey),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data?.data();
                return _MenuEditForm(
                  key: ValueKey('form-$_dateKey'),
                  hostelId: widget.hostelId,
                  dateKey: _dateKey,
                  existing: data,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Edit form ─────────────────────────────────────────────────────────────

class _MenuEditForm extends StatefulWidget {
  final String hostelId;
  final String dateKey;
  final Map<String, dynamic>? existing;

  const _MenuEditForm({
    super.key,
    required this.hostelId,
    required this.dateKey,
    required this.existing,
  });

  @override
  State<_MenuEditForm> createState() => _MenuEditFormState();
}

class _MenuEditFormState extends State<_MenuEditForm> {
  late TextEditingController _bTimeCtrl;
  late TextEditingController _bItemsCtrl;
  late TextEditingController _bNoteCtrl;
  late TextEditingController _lTimeCtrl;
  late TextEditingController _lItemsCtrl;
  late TextEditingController _lNoteCtrl;
  late TextEditingController _dTimeCtrl;
  late TextEditingController _dItemsCtrl;
  late TextEditingController _dNoteCtrl;
  late TextEditingController _noteCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.existing?['breakfast'] as Map<String, dynamic>? ?? {};
    final l = widget.existing?['lunch'] as Map<String, dynamic>? ?? {};
    final d = widget.existing?['dinner'] as Map<String, dynamic>? ?? {};
    _bTimeCtrl = TextEditingController(text: b['time'] as String? ?? '08:00 AM');
    _bItemsCtrl = TextEditingController(text: b['items'] as String? ?? '');
    _bNoteCtrl = TextEditingController(text: b['statusNote'] as String? ?? '');
    _lTimeCtrl = TextEditingController(text: l['time'] as String? ?? '01:00 PM');
    _lItemsCtrl = TextEditingController(text: l['items'] as String? ?? '');
    _lNoteCtrl = TextEditingController(text: l['statusNote'] as String? ?? '');
    _dTimeCtrl = TextEditingController(text: d['time'] as String? ?? '08:00 PM');
    _dItemsCtrl = TextEditingController(text: d['items'] as String? ?? '');
    _dNoteCtrl = TextEditingController(text: d['statusNote'] as String? ?? '');
    _noteCtrl = TextEditingController(
        text: widget.existing?['note'] as String? ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _bTimeCtrl, _bItemsCtrl, _bNoteCtrl,
      _lTimeCtrl, _lItemsCtrl, _lNoteCtrl,
      _dTimeCtrl, _dItemsCtrl, _dNoteCtrl,
      _noteCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTime(TextEditingController ctrl) async {
    final parts = ctrl.text.split(':');
    final h = int.tryParse(parts.first) ?? 8;
    final mRaw = parts.length > 1 ? parts[1].replaceAll(RegExp(r'[^0-9]'), '') : '00';
    final m = int.tryParse(mRaw) ?? 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: h % 24, minute: m.clamp(0, 59)),
    );
    if (picked != null && mounted) {
      ctrl.text = picked.format(context);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await HostelService().saveDailyMenu(
        hostelId: widget.hostelId,
        dateKey: widget.dateKey,
        breakfastTime: _bTimeCtrl.text.trim(),
        breakfastItems: _bItemsCtrl.text.trim(),
        breakfastNote: _bNoteCtrl.text.trim(),
        lunchTime: _lTimeCtrl.text.trim(),
        lunchItems: _lItemsCtrl.text.trim(),
        lunchNote: _lNoteCtrl.text.trim(),
        dinnerTime: _dTimeCtrl.text.trim(),
        dinnerItems: _dItemsCtrl.text.trim(),
        dinnerNote: _dNoteCtrl.text.trim(),
        note: _noteCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menu saved — tenants will be notified'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.existing != null)
            _UpdatedBadge(widget.existing!['updatedAt'] as Timestamp?),
          _MealSection(
            icon: Icons.wb_sunny_outlined,
            label: 'Breakfast (Morning)',
            color: Colors.orange,
            timeCtrl: _bTimeCtrl,
            itemsCtrl: _bItemsCtrl,
            noteCtrl: _bNoteCtrl,
            onPickTime: () => _pickTime(_bTimeCtrl),
          ),
          const SizedBox(height: 12),
          _MealSection(
            icon: Icons.lunch_dining_outlined,
            label: 'Lunch (Afternoon)',
            color: Colors.green,
            timeCtrl: _lTimeCtrl,
            itemsCtrl: _lItemsCtrl,
            noteCtrl: _lNoteCtrl,
            onPickTime: () => _pickTime(_lTimeCtrl),
          ),
          const SizedBox(height: 12),
          _MealSection(
            icon: Icons.nightlight_outlined,
            label: 'Dinner (Night)',
            color: Colors.indigo,
            timeCtrl: _dTimeCtrl,
            itemsCtrl: _dItemsCtrl,
            noteCtrl: _dNoteCtrl,
            onPickTime: () => _pickTime(_dTimeCtrl),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Special note (optional)',
              hintText: 'e.g. No meat today, Festival special...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note_outlined),
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save menu & notify tenants'),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _UpdatedBadge extends StatelessWidget {
  final Timestamp? updatedAt;
  const _UpdatedBadge(this.updatedAt);

  @override
  Widget build(BuildContext context) {
    if (updatedAt == null) return const SizedBox.shrink();
    final d = updatedAt!.toDate();
    final s =
        '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline,
              size: 14, color: Colors.teal.shade700),
          const SizedBox(width: 6),
          Text('Last saved: $s',
              style: TextStyle(fontSize: 12, color: Colors.teal.shade700)),
        ],
      ),
    );
  }
}

// ─── Single meal section ──────────────────────────────────────────────────

class _MealSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final TextEditingController timeCtrl;
  final TextEditingController itemsCtrl;
  final TextEditingController noteCtrl;
  final VoidCallback onPickTime;

  const _MealSection({
    required this.icon,
    required this.label,
    required this.color,
    required this.timeCtrl,
    required this.itemsCtrl,
    required this.noteCtrl,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: timeCtrl,
                        readOnly: true,
                        onTap: onPickTime,
                        decoration: InputDecoration(
                          labelText: 'Time',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: Icon(Icons.access_time,
                              size: 18, color: color),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: itemsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Food items',
                    hintText: 'e.g. Idli, Sambar, Coconut Chutney, Coffee',
                    border: OutlineInputBorder(),
                    isDense: true,
                    helperText: 'Separate items with commas',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: 'Availability note (optional)',
                    hintText: 'e.g. Rice not available today, providing Roti',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.warning_amber_outlined,
                        size: 18, color: color.withValues(alpha: 0.7)),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Read-only menu view (reusable widget) ────────────────────────────────

class DailyMenuView extends StatelessWidget {
  final String hostelId;
  final DateTime date;
  const DailyMenuView({super.key, required this.hostelId, required this.date});

  @override
  Widget build(BuildContext context) {
    final dateKey = HostelService.menuDateKey(date);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          HostelService().watchDailyMenu(hostelId: hostelId, dateKey: dateKey),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator()));
        }
        final data = snap.data?.data();
        if (data == null) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restaurant_menu_outlined,
                      size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No menu set for this day',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }
        final note = data['note'] as String? ?? '';
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MealCard(
                  icon: Icons.wb_sunny_outlined,
                  label: 'Breakfast',
                  color: Colors.orange,
                  meal: data['breakfast'] as Map<String, dynamic>?),
              const SizedBox(height: 8),
              _MealCard(
                  icon: Icons.lunch_dining_outlined,
                  label: 'Lunch',
                  color: Colors.green,
                  meal: data['lunch'] as Map<String, dynamic>?),
              const SizedBox(height: 8),
              _MealCard(
                  icon: Icons.nightlight_outlined,
                  label: 'Dinner',
                  color: Colors.indigo,
                  meal: data['dinner'] as Map<String, dynamic>?),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(note,
                              style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MealCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Map<String, dynamic>? meal;
  const _MealCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.meal});

  @override
  Widget build(BuildContext context) {
    final time = meal?['time'] as String? ?? '';
    final rawItems = meal?['items'] as String? ?? '';
    final statusNote = meal?['statusNote'] as String? ?? '';
    final items = rawItems
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color.withValues(alpha: 0.1),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontSize: 13)),
                const Spacer(),
                if (time.isNotEmpty)
                  Text(time,
                      style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (statusNote.isNotEmpty)
            Container(
              color: Colors.orange.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(statusNote,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.orange)),
                  ),
                ],
              ),
            ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Not set',
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                      fontSize: 13)),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: items
                    .map((item) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: color.withValues(alpha: 0.3)),
                          ),
                          child: Text(item,
                              style: TextStyle(
                                  fontSize: 12, color: color.withValues(alpha: 0.9))),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

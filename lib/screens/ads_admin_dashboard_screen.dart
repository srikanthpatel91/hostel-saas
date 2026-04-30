import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/ads_service.dart';

class AdsAdminDashboardScreen extends StatelessWidget {
  const AdsAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ads Dashboard')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New ad campaign'),
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => const _CreateAdSheet(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AdsService().watchAllAds(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final ads = snap.data?.docs ?? [];

          // Aggregate KPIs
          int totalActive = 0, totalImpressions = 0, totalClicks = 0, totalCompletions = 0;
          int totalBudget = 0, totalSpent = 0;
          for (final d in ads) {
            final data = d.data();
            if (data['status'] == 'active') totalActive++;
            totalImpressions += (data['totalImpressions'] as num?)?.toInt() ?? 0;
            totalClicks += (data['totalClicks'] as num?)?.toInt() ?? 0;
            totalCompletions += (data['completions'] as num?)?.toInt() ?? 0;
            final budget = (data['budget'] as num?)?.toInt() ?? 0;
            final remaining = (data['remainingBudget'] as num?)?.toInt() ?? budget;
            totalBudget += budget;
            totalSpent += budget - remaining;
          }
          final ctr = totalImpressions > 0
              ? (totalClicks / totalImpressions * 100).toStringAsFixed(1)
              : '0.0';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── KPI row ──────────────────────────────────────────────────
                _SectionLabel('Platform KPIs'),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.0,
                  children: [
                    _KpiTile(label: 'Active Campaigns', value: '$totalActive',
                        icon: Icons.campaign_outlined, color: Colors.teal),
                    _KpiTile(label: 'Total Impressions', value: '$totalImpressions',
                        icon: Icons.visibility_outlined, color: Colors.blue),
                    _KpiTile(label: 'Total Clicks', value: '$totalClicks',
                        icon: Icons.ads_click, color: Colors.orange),
                    _KpiTile(label: 'Avg CTR', value: '$ctr%',
                        icon: Icons.percent, color: Colors.purple),
                    _KpiTile(label: 'Completions', value: '$totalCompletions',
                        icon: Icons.check_circle_outline, color: Colors.green),
                    _KpiTile(label: 'Budget Spent', value: '₹$totalSpent / ₹$totalBudget',
                        icon: Icons.monetization_on_outlined, color: Colors.red),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Category breakdown ───────────────────────────────────────
                if (ads.isNotEmpty) ...[
                  _SectionLabel('Campaigns by Category'),
                  const SizedBox(height: 10),
                  _CategoryBreakdown(ads: ads),
                  const SizedBox(height: 24),
                ],

                // ── Ad list ──────────────────────────────────────────────────
                Row(
                  children: [
                    _SectionLabel('All Campaigns (${ads.length})'),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 10),

                if (ads.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.campaign_outlined, size: 56, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No campaigns yet', style: TextStyle(color: Colors.grey)),
                          SizedBox(height: 6),
                          Text('Create your first ad campaign using the button below.',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  ...ads.map((doc) => _AdCampaignCard(
                        adId: doc.id,
                        data: doc.data(),
                      )),
                const SizedBox(height: 96),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

// ─── KPI tile ─────────────────────────────────────────────────────────────────

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(label,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Category breakdown ───────────────────────────────────────────────────────

class _CategoryBreakdown extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> ads;
  const _CategoryBreakdown({required this.ads});

  @override
  Widget build(BuildContext context) {
    final Map<String, int> catCount = {};
    for (final d in ads) {
      final cat = d.data()['category'] as String? ?? 'Other';
      catCount[cat] = (catCount[cat] ?? 0) + 1;
    }
    final sorted = catCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    const colors = [
      Colors.teal, Colors.blue, Colors.orange, Colors.purple,
      Colors.green, Colors.red, Colors.amber, Colors.cyan,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sorted.indexed.map(((int, MapEntry<String, int>) entry) {
        final (i, e) = entry;
        final color = colors[i % colors.length];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            '${e.key}  ${e.value}',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Ad campaign card ─────────────────────────────────────────────────────────

class _AdCampaignCard extends StatelessWidget {
  final String adId;
  final Map<String, dynamic> data;
  const _AdCampaignCard({required this.adId, required this.data});

  Color _statusColor(String status) => switch (status) {
        'active' => Colors.green,
        'paused' => Colors.orange,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final advertiser = data['advertiserName'] as String? ?? '';
    final type = data['type'] as String? ?? 'image';
    final status = data['status'] as String? ?? 'active';
    final category = data['category'] as String? ?? '';
    final duration = (data['duration'] as num?)?.toInt() ?? 30;
    final impressions = (data['totalImpressions'] as num?)?.toInt() ?? 0;
    final clicks = (data['totalClicks'] as num?)?.toInt() ?? 0;
    final completions = (data['completions'] as num?)?.toInt() ?? 0;
    final budget = (data['budget'] as num?)?.toInt() ?? 0;
    final remaining = (data['remainingBudget'] as num?)?.toInt() ?? budget;
    final spent = budget - remaining;
    final ctr = impressions > 0
        ? '${(clicks / impressions * 100).toStringAsFixed(1)}%'
        : '0%';
    final budgetPct = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(advertiser,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                // Status toggle
                GestureDetector(
                  onTap: () => AdsService().updateAdStatus(
                    adId: adId,
                    status: status == 'active' ? 'paused' : 'active',
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _statusColor(status).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(status)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.grey),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete campaign?'),
                        content: Text('"$title" will be permanently removed.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) AdsService().deleteAd(adId);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Tags
            Wrap(
              spacing: 6,
              children: [
                _Tag(type.toUpperCase(), Colors.indigo),
                _Tag('${duration}s', Colors.teal),
                _Tag(category, Colors.orange),
              ],
            ),
            const SizedBox(height: 12),

            // Stats row
            Row(
              children: [
                _StatPill('👁 $impressions', 'views'),
                const SizedBox(width: 10),
                _StatPill('👆 $clicks', 'clicks'),
                const SizedBox(width: 10),
                _StatPill('✅ $completions', 'complete'),
                const SizedBox(width: 10),
                _StatPill('📊 $ctr', 'CTR'),
              ],
            ),
            const SizedBox(height: 10),

            // Budget progress
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: budgetPct,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(
                          budgetPct > 0.8 ? Colors.red : Colors.teal),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('₹$spent / ₹$budget',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  const _StatPill(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
          Text(label,
              style:
                  TextStyle(fontSize: 9, color: Colors.grey.shade500)),
        ],
      );
}

// ─── Create Ad bottom sheet ───────────────────────────────────────────────────

class _CreateAdSheet extends StatefulWidget {
  const _CreateAdSheet();

  @override
  State<_CreateAdSheet> createState() => _CreateAdSheetState();
}

class _CreateAdSheetState extends State<_CreateAdSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _advertiserCtrl = TextEditingController();
  final _mediaUrlCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  String _type = 'image';
  String _targetGender = 'all';
  String _category = AdsService.adCategories.first;
  int _duration = 30;
  int _cpm = 2000;
  int _ageMin = 18;
  int _ageMax = 45;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _advertiserCtrl.dispose();
    _mediaUrlCtrl.dispose();
    _budgetCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AdsService().createAd(
        title: _titleCtrl.text,
        advertiserName: _advertiserCtrl.text,
        type: _type,
        mediaUrl: _mediaUrlCtrl.text,
        duration: _duration,
        targetGender: _targetGender,
        targetAgeMin: _ageMin,
        targetAgeMax: _ageMax,
        targetCity: _cityCtrl.text,
        category: _category,
        budget: int.parse(_budgetCtrl.text.trim()),
        cpm: _cpm,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Campaign created and set to active'),
          backgroundColor: Colors.teal,
        ));
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

  String _fmtDate(DateTime d) {
    const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.6,
      expand: false,
      builder: (_, controller) => SingleChildScrollView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.campaign_outlined, color: Colors.teal),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('New Ad Campaign',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(height: 20),
              _Label('Ad Details'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Ad title *', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _advertiserCtrl,
                decoration: const InputDecoration(
                    labelText: 'Advertiser name *', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _mediaUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Media URL (image/video) *',
                  border: OutlineInputBorder(),
                  hintText: 'https://...',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              _Label('Ad Type & Duration'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                          labelText: 'Type', border: OutlineInputBorder()),
                      items: AdsService.adTypes
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setState(() => _type = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _duration,
                      decoration: const InputDecoration(
                          labelText: 'Duration', border: OutlineInputBorder()),
                      items: AdsService.durationOptions
                          .map((d) =>
                              DropdownMenuItem(value: d, child: Text('${d}s')))
                          .toList(),
                      onChanged: (v) => setState(() => _duration = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Label('Targeting'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                    labelText: 'Category', border: OutlineInputBorder()),
                items: AdsService.adCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _targetGender,
                      decoration: const InputDecoration(
                          labelText: 'Gender', border: OutlineInputBorder()),
                      items: AdsService.genderOptions
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setState(() => _targetGender = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'City (blank = all)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Age range
              Row(children: [
                const Text('Age range: ', style: TextStyle(fontSize: 13)),
                Text('$_ageMin – $_ageMax',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
              RangeSlider(
                values: RangeValues(_ageMin.toDouble(), _ageMax.toDouble()),
                min: 13,
                max: 70,
                divisions: 57,
                labels: RangeLabels('$_ageMin', '$_ageMax'),
                onChanged: (r) => setState(() {
                  _ageMin = r.start.round();
                  _ageMax = r.end.round();
                }),
              ),
              const SizedBox(height: 14),
              _Label('Budget & Dates'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _budgetCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Total budget (₹) *',
                          prefixText: '₹ ',
                          border: OutlineInputBorder()),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (int.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _cpm,
                      decoration: const InputDecoration(
                          labelText: 'CPM (₹ per 1k views)',
                          border: OutlineInputBorder()),
                      items: [500, 1000, 2000, 5000]
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text('₹$c')))
                          .toList(),
                      onChanged: (v) => setState(() => _cpm = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _DateTile(
                      label: 'Start date',
                      value: _fmtDate(_startDate),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) setState(() => _startDate = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateTile(
                      label: 'End date',
                      value: _fmtDate(_endDate),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _endDate,
                          firstDate: _startDate,
                          lastDate: _startDate.add(const Duration(days: 365)),
                        );
                        if (d != null) setState(() => _endDate = d);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.rocket_launch_outlined),
                label: Text(_saving ? 'Creating...' : 'Launch Campaign'),
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.primary),
      );
}

class _DateTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateTile({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: label,
              suffixIcon: const Icon(Icons.calendar_today, size: 16),
              border: const OutlineInputBorder()),
          child: Text(value, style: const TextStyle(fontSize: 13)),
        ),
      );
}

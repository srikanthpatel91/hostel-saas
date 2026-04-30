import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

// ─── Plan definitions ─────────────────────────────────────────────────────────

class _Plan {
  final String id;
  final String name;
  final int monthlyPrice;
  final String tagline;
  final IconData icon;
  final Color color;
  final int? roomLimit; // null = unlimited
  final List<_Feature> features;

  const _Plan({
    required this.id,
    required this.name,
    required this.monthlyPrice,
    required this.tagline,
    required this.icon,
    required this.color,
    this.roomLimit,
    required this.features,
  });

  int yearlyPrice() => (monthlyPrice * 10).toInt(); // 2 months free
  bool get recommended => id == 'pro';
}

class _Feature {
  final String label;
  final bool included;
  const _Feature(this.label, {this.included = true});
}

const _plans = [
  _Plan(
    id: 'basic',
    name: 'Basic',
    monthlyPrice: 499,
    tagline: 'Perfect to get started',
    icon: Icons.home_outlined,
    color: Colors.blueGrey,
    roomLimit: 50,
    features: [
      _Feature('Up to 50 rooms'),
      _Feature('Unlimited guests'),
      _Feature('Invoice generation'),
      _Feature('Expense tracking'),
      _Feature('Financials dashboard'),
      _Feature('Complaints management'),
      _Feature('Notice board'),
      _Feature('Tenant app access', included: false),
      _Feature('Wallet & referrals', included: false),
      _Feature('Staff / manager accounts', included: false),
      _Feature('Kitchen & AI features', included: false),
      _Feature('Multi-hostel management', included: false),
    ],
  ),
  _Plan(
    id: 'pro',
    name: 'Pro',
    monthlyPrice: 999,
    tagline: 'For growing hostels',
    icon: Icons.rocket_launch_outlined,
    color: Colors.teal,
    features: [
      _Feature('Unlimited rooms'),
      _Feature('Unlimited guests'),
      _Feature('Invoice generation'),
      _Feature('Expense tracking'),
      _Feature('Financials & analytics'),
      _Feature('Complaints management'),
      _Feature('Notice board'),
      _Feature('Tenant app access'),
      _Feature('Wallet & referrals'),
      _Feature('Staff / manager accounts'),
      _Feature('Kitchen & AI features', included: false),
      _Feature('Multi-hostel management', included: false),
    ],
  ),
  _Plan(
    id: 'enterprise',
    name: 'Enterprise',
    monthlyPrice: 2499,
    tagline: 'Full power, multi-property',
    icon: Icons.corporate_fare_outlined,
    color: Colors.deepPurple,
    features: [
      _Feature('Unlimited rooms'),
      _Feature('Unlimited guests'),
      _Feature('Invoice generation'),
      _Feature('Expense tracking'),
      _Feature('Financials & analytics'),
      _Feature('Complaints management'),
      _Feature('Notice board'),
      _Feature('Tenant app access'),
      _Feature('Wallet & referrals'),
      _Feature('Staff / manager accounts'),
      _Feature('Kitchen & AI features'),
      _Feature('Multi-hostel management'),
    ],
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class SubscriptionScreen extends StatefulWidget {
  final String hostelId;
  const SubscriptionScreen({super.key, required this.hostelId});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _yearly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plans & Billing')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: HostelService().watchHostel(widget.hostelId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data?.data() ?? {};
          final sub = data['subscription'] as Map<String, dynamic>? ?? {};
          final status = sub['status'] as String? ?? 'trial';
          final currentPlan = sub['plan'] as String? ?? '';
          final trialEnd = (sub['trialEndsAt'] as Timestamp?)?.toDate();
          final daysLeft = trialEnd != null
              ? trialEnd.difference(DateTime.now()).inDays.clamp(0, 999)
              : 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Current status banner
                _CurrentStatusBanner(
                    status: status,
                    planId: currentPlan,
                    daysLeft: daysLeft),
                const SizedBox(height: 24),

                // Monthly / Yearly toggle
                _BillingToggle(
                  yearly: _yearly,
                  onChanged: (v) => setState(() => _yearly = v),
                ),
                const SizedBox(height: 8),
                if (_yearly)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '🎉 Save 2 months with yearly billing',
                        style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                // Plan cards
                ..._plans.map((plan) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _PlanCard(
                        plan: plan,
                        yearly: _yearly,
                        isCurrent:
                            currentPlan == plan.id && status == 'active',
                        isTrialActive: status == 'trial',
                        onSelect: () => _handleSelect(context, plan),
                      ),
                    )),

                // Razorpay note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 18, color: Colors.grey),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Razorpay payment integration coming soon. '
                          'Plans are currently in preview mode.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleSelect(BuildContext context, _Plan plan) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Subscribe to ${plan.name}?'),
        content: Text(
          'You selected the ${plan.name} plan at '
          '₹${_yearly ? plan.yearlyPrice() : plan.monthlyPrice}/'
          '${_yearly ? 'yr' : 'mo'}.\n\n'
          'Razorpay payment will be available at launch.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')),
        ],
      ),
    );
  }
}

// ─── Current status banner ────────────────────────────────────────────────────

class _CurrentStatusBanner extends StatelessWidget {
  final String status;
  final String planId;
  final int daysLeft;
  const _CurrentStatusBanner(
      {required this.status, required this.planId, required this.daysLeft});

  @override
  Widget build(BuildContext context) {
    final isTrial = status == 'trial';
    final isActive = status == 'active';
    final isUrgent = isTrial && daysLeft <= 3;

    final Color bg;
    final Color fg;
    final IconData icon;
    final String title;
    final String sub;

    if (isActive) {
      final planName = _plans
          .where((p) => p.id == planId)
          .map((p) => p.name)
          .firstOrNull ?? planId.toUpperCase();
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
      icon = Icons.verified_outlined;
      title = '$planName — Active';
      sub = 'All features unlocked';
    } else if (isTrial && isUrgent) {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
      icon = Icons.warning_amber_rounded;
      title = 'Trial ends in $daysLeft day${daysLeft == 1 ? '' : 's'}!';
      sub = 'Subscribe now to avoid losing access';
    } else if (isTrial) {
      bg = Colors.amber.shade50;
      fg = Colors.amber.shade900;
      icon = Icons.hourglass_top_outlined;
      title = 'Free Trial — $daysLeft days left';
      sub = 'No payment needed yet';
    } else {
      bg = Colors.grey.shade100;
      fg = Colors.grey.shade800;
      icon = Icons.block_outlined;
      title = 'Subscription ended';
      sub = 'Choose a plan to continue';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: fg)),
                const SizedBox(height: 2),
                Text(sub,
                    style: TextStyle(fontSize: 13, color: fg)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Billing toggle ───────────────────────────────────────────────────────────

class _BillingToggle extends StatelessWidget {
  final bool yearly;
  final ValueChanged<bool> onChanged;
  const _BillingToggle({required this.yearly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Monthly',
            style: TextStyle(
                fontWeight:
                    !yearly ? FontWeight.w700 : FontWeight.normal,
                color: !yearly ? cs.primary : cs.onSurface)),
        const SizedBox(width: 12),
        Switch(
          value: yearly,
          onChanged: onChanged,
          activeThumbColor: cs.primary,
        ),
        const SizedBox(width: 12),
        Text('Yearly',
            style: TextStyle(
                fontWeight:
                    yearly ? FontWeight.w700 : FontWeight.normal,
                color: yearly ? cs.primary : cs.onSurface)),
        const SizedBox(width: 6),
        if (yearly)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('-17%',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

// ─── Plan card ────────────────────────────────────────────────────────────────

class _PlanCard extends StatefulWidget {
  final _Plan plan;
  final bool yearly;
  final bool isCurrent;
  final bool isTrialActive;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.plan,
    required this.yearly,
    required this.isCurrent,
    required this.isTrialActive,
    required this.onSelect,
  });

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = widget.plan;
    final price = widget.yearly ? p.yearlyPrice() : p.monthlyPrice;
    final period = widget.yearly ? 'yr' : 'mo';
    final isRec = p.recommended;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRec
              ? p.color
              : widget.isCurrent
                  ? cs.primary
                  : cs.outlineVariant,
          width: isRec || widget.isCurrent ? 2 : 1,
        ),
        color: isRec
            ? p.color.withValues(alpha: 0.04)
            : cs.surface,
        boxShadow: isRec
            ? [
                BoxShadow(
                    color: p.color.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ]
            : null,
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: p.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(p.icon, color: p.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(p.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17)),
                          if (isRec) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: p.color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('POPULAR',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5)),
                            ),
                          ],
                          if (widget.isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('CURRENT',
                                  style: TextStyle(
                                      color: cs.onPrimaryContainer,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ],
                      ),
                      Text(p.tagline,
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Price
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹$price',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: p.color)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 2),
                  child: Text('/$period',
                      style: TextStyle(
                          fontSize: 14,
                          color:
                              cs.onSurface.withValues(alpha: 0.5))),
                ),
                if (widget.yearly) ...[
                  const Spacer(),
                  Text(
                    '₹${p.monthlyPrice}/mo equiv.',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ],
            ),
          ),

          // Top 4 features always visible
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: p.features
                  .take(4)
                  .map((f) => _FeatureRow(f: f))
                  .toList(),
            ),
          ),

          // Expandable remaining features
          if (p.features.length > 4) ...[
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded
                    ? 'Show less'
                    : 'See all ${p.features.length} features',
                style: TextStyle(color: p.color, fontSize: 13),
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Column(
                  children: p.features
                      .skip(4)
                      .map((f) => _FeatureRow(f: f))
                      .toList(),
                ),
              ),
          ],

          // CTA
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: widget.isCurrent
                  ? OutlinedButton(
                      onPressed: null,
                      child: const Text('Current plan'),
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: p.color,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: widget.onSelect,
                      child: Text(
                        widget.isTrialActive
                            ? 'Subscribe to ${p.name}'
                            : 'Upgrade to ${p.name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final _Feature f;
  const _FeatureRow({required this.f});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            f.included ? Icons.check_circle : Icons.cancel_outlined,
            size: 16,
            color: f.included ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Text(
            f.label,
            style: TextStyle(
              fontSize: 13,
              color: f.included
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.grey.shade400,
              decoration: f.included ? null : TextDecoration.lineThrough,
            ),
          ),
        ],
      ),
    );
  }
}

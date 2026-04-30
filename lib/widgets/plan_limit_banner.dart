import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/subscription_screen.dart';

/// Drop this anywhere in the owner UI to show an upgrade prompt
/// when the hostel is approaching or has hit a plan limit.
///
/// Usage:
///   PlanLimitBanner(hostelId: hostelId, resource: 'rooms', current: count)
class PlanLimitBanner extends StatelessWidget {
  final String hostelId;
  final String resource; // 'rooms', 'guests', etc.
  final int current;

  const PlanLimitBanner({
    super.key,
    required this.hostelId,
    required this.resource,
    required this.current,
  });

  static const _limits = {
    'basic': {'rooms': 50},
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hostels')
          .doc(hostelId)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final sub = data['subscription'] as Map<String, dynamic>? ?? {};
        final plan = (sub['plan'] as String? ?? 'basic').toLowerCase();

        final planLimits = _limits[plan];
        if (planLimits == null) return const SizedBox.shrink(); // unlimited plan

        final limit = planLimits[resource];
        if (limit == null) return const SizedBox.shrink();

        final pct = current / limit;
        if (pct < 0.8) return const SizedBox.shrink(); // under 80% — stay quiet

        final atLimit = current >= limit;

        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SubscriptionScreen(hostelId: hostelId),
          )),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: atLimit
                  ? Colors.red.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: atLimit
                    ? Colors.red.shade200
                    : Colors.orange.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  atLimit ? Icons.lock_outline : Icons.warning_amber_rounded,
                  size: 20,
                  color: atLimit
                      ? Colors.red.shade700
                      : Colors.orange.shade800,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        atLimit
                            ? '$current/$limit $resource — limit reached on ${_planLabel(plan)}'
                            : '$current/$limit $resource used on ${_planLabel(plan)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: atLimit
                              ? Colors.red.shade800
                              : Colors.orange.shade900,
                        ),
                      ),
                      if (atLimit)
                        Text(
                          'Upgrade to Pro for unlimited $resource',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: atLimit ? Colors.red : Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Upgrade',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _planLabel(String plan) => switch (plan) {
        'basic' => 'Basic',
        'pro' => 'Pro',
        'enterprise' => 'Enterprise',
        _ => plan,
      };
}

/// Compact inline chip variant — use inside AppBar or card headers.
class PlanLimitChip extends StatelessWidget {
  final String hostelId;
  final String resource;
  final int current;

  const PlanLimitChip({
    super.key,
    required this.hostelId,
    required this.resource,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hostels')
          .doc(hostelId)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final sub = data['subscription'] as Map<String, dynamic>? ?? {};
        final plan = (sub['plan'] as String? ?? 'basic').toLowerCase();

        const limits = {'basic': {'rooms': 50}};
        final limit = limits[plan]?[resource];
        if (limit == null) return const SizedBox.shrink();

        final atLimit = current >= limit;
        final nearLimit = current >= (limit * 0.8).toInt();
        if (!nearLimit) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SubscriptionScreen(hostelId: hostelId),
          )),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: atLimit ? Colors.red.shade100 : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  atLimit ? Icons.lock_outline : Icons.warning_amber_rounded,
                  size: 12,
                  color: atLimit
                      ? Colors.red.shade700
                      : Colors.orange.shade800,
                ),
                const SizedBox(width: 4),
                Text(
                  '$current/$limit',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: atLimit
                          ? Colors.red.shade700
                          : Colors.orange.shade800),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

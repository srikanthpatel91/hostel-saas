import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Role-specific summary screen shown as the "My Report" tab in StaffShellScreen.
/// Each role sees metrics relevant to their work.
class StaffReportScreen extends StatelessWidget {
  final String hostelId;
  final String staffRole;
  const StaffReportScreen(
      {super.key, required this.hostelId, required this.staffRole});

  @override
  Widget build(BuildContext context) {
    return switch (staffRole) {
      'manager' || 'head_master' => _ManagerReport(hostelId: hostelId),
      'warden'                   => _WardenReport(hostelId: hostelId),
      'chef'                     => _ChefReport(hostelId: hostelId),
      'cleaning_head'            => _CleaningReport(hostelId: hostelId),
      'security'                 => _SecurityReport(hostelId: hostelId),
      _                          => _GenericReport(hostelId: hostelId),
    };
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

Widget _statCard(BuildContext context,
    {required IconData icon,
    required String label,
    required String value,
    Color? color}) {
  final cs = Theme.of(context).colorScheme;
  final c = color ?? cs.primary;
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: c),
            const SizedBox(width: 6),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)))),
          ]),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800, color: c)),
        ],
      ),
    ),
  );
}

SliverToBoxAdapter _sectionHeader(String title) => SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
        child: Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      ),
    );

// ─── Manager / Head Master report ────────────────────────────────────────────

class _ManagerReport extends StatelessWidget {
  final String hostelId;
  const _ManagerReport({required this.hostelId});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    return Scaffold(
      appBar: AppBar(title: const Text('My Report')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('hostels')
            .doc(hostelId)
            .collection('rooms')
            .snapshots(),
        builder: (context, roomSnap) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db
                .collection('hostels')
                .doc(hostelId)
                .collection('guests')
                .where('isActive', isEqualTo: true)
                .snapshots(),
            builder: (context, guestSnap) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: db
                    .collection('hostels')
                    .doc(hostelId)
                    .collection('complaints')
                    .where('status', isEqualTo: 'open')
                    .snapshots(),
                builder: (context, compSnap) {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: db
                        .collection('hostels')
                        .doc(hostelId)
                        .collection('maintenance')
                        .where('status', isEqualTo: 'open')
                        .snapshots(),
                    builder: (context, maintSnap) {
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: db
                            .collection('hostels')
                            .doc(hostelId)
                            .collection('invoices')
                            .where('status', whereIn: ['pending', 'overdue'])
                            .snapshots(),
                        builder: (context, invSnap) {
                          final rooms = roomSnap.data?.docs ?? [];
                          final guests = guestSnap.data?.docs.length ?? 0;
                          final totalBeds = rooms.fold<int>(
                              0,
                              (s, d) =>
                                  s +
                                  ((d.data()['beds'] as num?)?.toInt() ?? 0));
                          final occupancy =
                              totalBeds > 0 ? (guests / totalBeds * 100).round() : 0;
                          final openComplaints =
                              compSnap.data?.docs.length ?? 0;
                          final openMaintenance =
                              maintSnap.data?.docs.length ?? 0;
                          final pendingInv =
                              invSnap.data?.docs.length ?? 0;

                          // Month revenue from invoices
                          final paidThisMonth = invSnap.data?.docs
                                  .where((d) {
                                    final status =
                                        d.data()['status'] as String?;
                                    final paidAt = (d.data()['paidAt']
                                            as Timestamp?)
                                        ?.toDate();
                                    return status == 'paid' &&
                                        paidAt != null &&
                                        paidAt.isAfter(monthStart);
                                  })
                                  .fold<int>(
                                      0,
                                      (s, d) =>
                                          s +
                                          ((d.data()['amount'] as num?)
                                                  ?.toInt() ??
                                              0)) ??
                              0;

                          return CustomScrollView(
                            slivers: [
                              _sectionHeader('Occupancy'),
                              SliverGrid(
                                delegate: SliverChildListDelegate([
                                  _statCard(context,
                                      icon: Icons.people_outline,
                                      label: 'Active Guests',
                                      value: '$guests'),
                                  _statCard(context,
                                      icon: Icons.bed_outlined,
                                      label: 'Total Beds',
                                      value: '$totalBeds'),
                                  _statCard(context,
                                      icon: Icons.donut_small_outlined,
                                      label: 'Occupancy %',
                                      value: '$occupancy%',
                                      color: occupancy >= 80
                                          ? Colors.green
                                          : Colors.orange),
                                  _statCard(context,
                                      icon: Icons.receipt_long_outlined,
                                      label: 'Revenue This Month',
                                      value: '₹$paidThisMonth',
                                      color: Colors.teal),
                                ]),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.5,
                                ),
                              ),
                              _sectionHeader('Action Items'),
                              SliverGrid(
                                delegate: SliverChildListDelegate([
                                  _statCard(context,
                                      icon: Icons.report_problem_outlined,
                                      label: 'Open Complaints',
                                      value: '$openComplaints',
                                      color: openComplaints > 0
                                          ? Colors.orange
                                          : Colors.green),
                                  _statCard(context,
                                      icon: Icons.build_outlined,
                                      label: 'Open Maintenance',
                                      value: '$openMaintenance',
                                      color: openMaintenance > 0
                                          ? Colors.orange
                                          : Colors.green),
                                  _statCard(context,
                                      icon: Icons.warning_amber_outlined,
                                      label: 'Pending Invoices',
                                      value: '$pendingInv',
                                      color: pendingInv > 0
                                          ? Colors.red
                                          : Colors.green),
                                ]),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.5,
                                ),
                              ),
                              const SliverToBoxAdapter(
                                  child: SizedBox(height: 32)),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Warden report ────────────────────────────────────────────────────────────

class _WardenReport extends StatelessWidget {
  final String hostelId;
  const _WardenReport({required this.hostelId});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('My Report')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('hostels')
            .doc(hostelId)
            .collection('guests')
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, guestSnap) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db
                .collection('hostels')
                .doc(hostelId)
                .collection('complaints')
                .snapshots(),
            builder: (context, compSnap) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: db
                    .collection('hostels')
                    .doc(hostelId)
                    .collection('checkout_requests')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, coSnap) {
                  final guests = guestSnap.data?.docs.length ?? 0;
                  final allComplaints = compSnap.data?.docs ?? [];
                  final openComplaints =
                      allComplaints.where((d) => d.data()['status'] == 'open').length;
                  final resolvedComplaints =
                      allComplaints.where((d) => d.data()['status'] == 'resolved').length;
                  final pendingCheckouts = coSnap.data?.docs.length ?? 0;

                  return CustomScrollView(
                    slivers: [
                      _sectionHeader('Tenants'),
                      SliverGrid(
                        delegate: SliverChildListDelegate([
                          _statCard(context,
                              icon: Icons.people_outline,
                              label: 'Active Tenants',
                              value: '$guests'),
                          _statCard(context,
                              icon: Icons.exit_to_app_outlined,
                              label: 'Pending Checkouts',
                              value: '$pendingCheckouts',
                              color: pendingCheckouts > 0
                                  ? Colors.orange
                                  : Colors.green),
                        ]),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.5,
                        ),
                      ),
                      _sectionHeader('Complaints'),
                      SliverGrid(
                        delegate: SliverChildListDelegate([
                          _statCard(context,
                              icon: Icons.report_problem_outlined,
                              label: 'Open',
                              value: '$openComplaints',
                              color: openComplaints > 0
                                  ? Colors.orange
                                  : Colors.green),
                          _statCard(context,
                              icon: Icons.check_circle_outline,
                              label: 'Resolved',
                              value: '$resolvedComplaints',
                              color: Colors.green),
                        ]),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.5,
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Chef report ──────────────────────────────────────────────────────────────

class _ChefReport extends StatelessWidget {
  final String hostelId;
  const _ChefReport({required this.hostelId});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('My Report')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('hostels')
            .doc(hostelId)
            .collection('guests')
            .where('isActive', isEqualTo: true)
            .where('mealPlan', isNull: false)
            .snapshots(),
        builder: (context, mealSnap) {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: db
                .collection('hostels')
                .doc(hostelId)
                .collection('daily_menu')
                .doc(dateKey)
                .snapshots(),
            builder: (context, menuSnap) {
              final mealSubscribers = mealSnap.data?.docs.length ?? 0;
              final menuData = menuSnap.data?.data() ?? {};
              final hasBreakfast =
                  (menuData['breakfast'] as Map?)?.isNotEmpty ?? false;
              final hasLunch =
                  (menuData['lunch'] as Map?)?.isNotEmpty ?? false;
              final hasDinner =
                  (menuData['dinner'] as Map?)?.isNotEmpty ?? false;
              final mealsPublished =
                  [hasBreakfast, hasLunch, hasDinner].where((v) => v).length;

              return CustomScrollView(
                slivers: [
                  _sectionHeader("Today's Menu"),
                  SliverGrid(
                    delegate: SliverChildListDelegate([
                      _statCard(context,
                          icon: Icons.restaurant_menu_outlined,
                          label: 'Meals Published Today',
                          value: '$mealsPublished / 3',
                          color: mealsPublished == 3
                              ? Colors.green
                              : Colors.orange),
                      _statCard(context,
                          icon: Icons.people_outline,
                          label: 'Meal Plan Subscribers',
                          value: '$mealSubscribers'),
                    ]),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                    ),
                  ),
                  _sectionHeader("Today's Status"),
                  SliverList(
                    delegate: SliverChildListDelegate([
                      _MealStatusTile(
                          meal: 'Breakfast', published: hasBreakfast),
                      _MealStatusTile(meal: 'Lunch', published: hasLunch),
                      _MealStatusTile(meal: 'Dinner', published: hasDinner),
                    ]),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _MealStatusTile extends StatelessWidget {
  final String meal;
  final bool published;
  const _MealStatusTile({required this.meal, required this.published});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        published ? Icons.check_circle : Icons.radio_button_unchecked,
        color: published ? Colors.green : Colors.grey,
      ),
      title: Text(meal),
      trailing: Text(
        published ? 'Published' : 'Not published',
        style: TextStyle(
            color: published ? Colors.green : Colors.orange, fontSize: 12),
      ),
    );
  }
}

// ─── Cleaning head report ─────────────────────────────────────────────────────

class _CleaningReport extends StatelessWidget {
  final String hostelId;
  const _CleaningReport({required this.hostelId});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('My Report')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('hostels')
            .doc(hostelId)
            .collection('maintenance')
            .snapshots(),
        builder: (context, snap) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db
                .collection('hostels')
                .doc(hostelId)
                .collection('rooms')
                .where('isUnderMaintenance', isEqualTo: true)
                .snapshots(),
            builder: (context, roomSnap) {
              final all = snap.data?.docs ?? [];
              final open =
                  all.where((d) => d.data()['status'] == 'open').length;
              final inProgress = all
                  .where((d) => d.data()['status'] == 'in_progress')
                  .length;
              final resolved =
                  all.where((d) => d.data()['status'] == 'resolved').length;
              final roomsUnderMaint = roomSnap.data?.docs.length ?? 0;

              return CustomScrollView(
                slivers: [
                  _sectionHeader('Maintenance Overview'),
                  SliverGrid(
                    delegate: SliverChildListDelegate([
                      _statCard(context,
                          icon: Icons.warning_amber_outlined,
                          label: 'Open',
                          value: '$open',
                          color: open > 0 ? Colors.red : Colors.green),
                      _statCard(context,
                          icon: Icons.pending_outlined,
                          label: 'In Progress',
                          value: '$inProgress',
                          color: Colors.orange),
                      _statCard(context,
                          icon: Icons.check_circle_outline,
                          label: 'Resolved',
                          value: '$resolved',
                          color: Colors.green),
                      _statCard(context,
                          icon: Icons.bed_outlined,
                          label: 'Rooms Under Maintenance',
                          value: '$roomsUnderMaint',
                          color: roomsUnderMaint > 0
                              ? Colors.orange
                              : Colors.green),
                    ]),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Security report ──────────────────────────────────────────────────────────

class _SecurityReport extends StatelessWidget {
  final String hostelId;
  const _SecurityReport({required this.hostelId});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('My Report')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('hostels')
            .doc(hostelId)
            .collection('guests')
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, guestSnap) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db
                .collection('hostels')
                .doc(hostelId)
                .collection('complaints')
                .where('status', isEqualTo: 'open')
                .snapshots(),
            builder: (context, compSnap) {
              final guests = guestSnap.data?.docs.length ?? 0;
              final openComplaints = compSnap.data?.docs.length ?? 0;

              // Count guests checked in today
              final today = DateTime.now();
              final checkedInToday = guestSnap.data?.docs.where((d) {
                    final joinedAt =
                        (d.data()['joinedAt'] as Timestamp?)?.toDate();
                    return joinedAt != null &&
                        joinedAt.year == today.year &&
                        joinedAt.month == today.month &&
                        joinedAt.day == today.day;
                  }).length ??
                  0;

              return CustomScrollView(
                slivers: [
                  _sectionHeader('Guest Activity'),
                  SliverGrid(
                    delegate: SliverChildListDelegate([
                      _statCard(context,
                          icon: Icons.people_outline,
                          label: 'Active Tenants',
                          value: '$guests'),
                      _statCard(context,
                          icon: Icons.login_outlined,
                          label: 'Checked In Today',
                          value: '$checkedInToday',
                          color: Colors.teal),
                      _statCard(context,
                          icon: Icons.report_problem_outlined,
                          label: 'Open Complaints',
                          value: '$openComplaints',
                          color: openComplaints > 0
                              ? Colors.orange
                              : Colors.green),
                    ]),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Generic staff report ─────────────────────────────────────────────────────

class _GenericReport extends StatelessWidget {
  final String hostelId;
  const _GenericReport({required this.hostelId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Report')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('hostels')
            .doc(hostelId)
            .collection('notices')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .snapshots(),
        builder: (context, snap) {
          final notices = snap.data?.docs ?? [];
          return CustomScrollView(
            slivers: [
              _sectionHeader('Recent Notices'),
              notices.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No notices yet',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final d = notices[i].data();
                          return ListTile(
                            leading: const Icon(Icons.campaign_outlined),
                            title: Text(d['message'] as String? ?? ''),
                            subtitle: Text(
                              (d['createdAt'] as Timestamp?)
                                      ?.toDate()
                                      .toString()
                                      .substring(0, 10) ??
                                  '',
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                        childCount: notices.length,
                      ),
                    ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }
}

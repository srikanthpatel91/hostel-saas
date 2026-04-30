import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';
import 'owner_shell_screen.dart';
import 'owner_onboarding_screen.dart';
import 'tenant_link_screen.dart';

/// Shown when an owner has 2+ hostels, or when they tap "My Hostels"
/// from inside any hostel shell.
///
/// [isHomeRoute] true  → no back button (this IS the root for this owner).
/// [isHomeRoute] false → back button is shown (user navigated here as switcher).
class HostelPickerScreen extends StatelessWidget {
  final bool isHomeRoute;
  const HostelPickerScreen({super.key, this.isHomeRoute = false});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !isHomeRoute,
        title: const Text('My Hostels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Sign out?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign out')),
                  ],
                ),
              );
              if (ok == true) {
                await HostelService().watchHostel('').listen((_) {}).cancel();
                // ignore: use_build_context_synchronously
                if (context.mounted) {
                  await FirebaseAuth.instance.signOut();
                }
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_business),
        label: const Text('Add hostel'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const OwnerOnboardingScreen(),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: HostelService().watchOwnerHostels(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.home_work_outlined,
                        size: 72, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('No hostels yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey)),
                    const SizedBox(height: 8),
                    const Text(
                      'Set up your hostel or link as a tenant to get started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      icon: const Icon(Icons.add_business),
                      label: const Text('Set up my hostel'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const OwnerOnboardingScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('or', style: TextStyle(color: Colors.grey)),
                      ),
                      Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.bed_outlined),
                      label: const Text("I'm a tenant — link my room"),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const TenantLinkScreen()),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      icon: const Icon(Icons.logout, size: 16),
                      label: const Text('Sign out'),
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade600),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Sign out?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel')),
                              TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Sign out')),
                            ],
                          ),
                        );
                        if (ok == true && context.mounted) {
                          await FirebaseAuth.instance.signOut();
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          // Sort by createdAt ascending so first hostel is at top
          final sorted = List.of(docs)
            ..sort((a, b) {
              final ta =
                  (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                      0;
              final tb =
                  (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                      0;
              return ta.compareTo(tb);
            });

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: sorted.length,
            itemBuilder: (ctx, i) {
              final doc = sorted[i];
              final data = doc.data();
              final hostelId = doc.id;
              final name = data['name'] as String? ?? '';
              final city = data['city'] as String? ?? '';
              final sub =
                  data['subscription'] as Map<String, dynamic>? ?? {};
              final status = sub['status'] as String? ?? 'unknown';
              final trialEnd =
                  (sub['trialEndsAt'] as Timestamp?)?.toDate();

              return _HostelCard(
                name: name,
                city: city,
                subscriptionStatus: status,
                trialEnd: trialEnd,
                hostelId: hostelId,
                onTap: () {
                  // Replace the current route so "back" doesn't return here
                  // when switching from within the shell; but if this IS the
                  // home route the navigator stack is already clean.
                  if (isHomeRoute) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => OwnerShellScreen(hostelId: hostelId),
                      ),
                    );
                  } else {
                    // Came from within a shell → pop all until root so the
                    // HomeScreen stream can naturally re-land on the picker,
                    // then push the chosen shell.
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OwnerShellScreen(hostelId: hostelId),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Hostel card ──────────────────────────────────────────────────────────────

class _HostelCard extends StatelessWidget {
  final String hostelId;
  final String name;
  final String city;
  final String subscriptionStatus;
  final DateTime? trialEnd;
  final VoidCallback onTap;

  const _HostelCard({
    required this.hostelId,
    required this.name,
    required this.city,
    required this.subscriptionStatus,
    required this.trialEnd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.teal.shade100,
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.teal.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(city,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    _SubBadge(
                        status: subscriptionStatus, trialEnd: trialEnd),
                  ],
                ),
              ),
              // Live stats: rooms + guests
              _HostelMiniStats(hostelId: hostelId),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubBadge extends StatelessWidget {
  final String status;
  final DateTime? trialEnd;
  const _SubBadge({required this.status, required this.trialEnd});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    switch (status) {
      case 'trial':
        final days = trialEnd?.difference(DateTime.now()).inDays ?? 0;
        label = 'Trial — $days day${days == 1 ? '' : 's'} left';
        color = days <= 3 ? Colors.red : Colors.amber.shade800;
      case 'active':
        label = 'Active';
        color = Colors.green;
      case 'expired':
        label = 'Expired';
        color = Colors.red;
      default:
        label = status;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// Shows live room + guest counts for a hostel without N+1 queries —
/// uses two sub-collection count streams.
class _HostelMiniStats extends StatelessWidget {
  final String hostelId;
  const _HostelMiniStats({required this.hostelId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hostels')
          .doc(hostelId)
          .collection('rooms')
          .snapshots(),
      builder: (context, roomSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('hostels')
              .doc(hostelId)
              .collection('guests')
              .where('isActive', isEqualTo: true)
              .snapshots(),
          builder: (context, guestSnap) {
            final rooms = roomSnap.data?.docs.length ?? 0;
            final guests = guestSnap.data?.docs.length ?? 0;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatChip(
                    icon: Icons.bed_outlined, value: '$rooms', label: 'rooms'),
                const SizedBox(height: 4),
                _StatChip(
                    icon: Icons.people_outline,
                    value: '$guests',
                    label: 'tenants'),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatChip(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 3),
        Text(
          '$value $label',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/hostel_service.dart';

class OwnerDashboardScreen extends StatelessWidget {
  final String hostelId;
  const OwnerDashboardScreen({super.key, required this.hostelId});

  @override
  Widget build(BuildContext context) {
    final hostelService = HostelService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Hostel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: hostelService.watchHostel(hostelId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Hostel not found'));
          }

          final data = snapshot.data!.data()!;
          final name = data['name'] as String? ?? '';
          final city = data['city'] as String? ?? '';
          final sub = data['subscription'] as Map<String, dynamic>? ?? {};
          final status = sub['status'] as String? ?? 'unknown';
          final trialEnd = (sub['trialEndsAt'] as Timestamp?)?.toDate();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HostelHeader(name: name, city: city),
                const SizedBox(height: 12),
                _TrialBanner(status: status, trialEnd: trialEnd),
                const SizedBox(height: 16),

                // Vacant beds hero card — the Esa owner's #1 pain
                _VacantBedsCard(hostelId: hostelId),
                const SizedBox(height: 24),

                // Three live-count cards
                _LiveCountCard(
                  icon: Icons.bed,
                  title: 'Rooms',
                  subtitle: 'Add and manage rooms',
                  collectionPath: 'hostels/$hostelId/rooms',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rooms screen — day 3')),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _LiveCountCard(
                  icon: Icons.people,
                  title: 'Guests',
                  subtitle: 'Add and manage tenants',
                  collectionPath: 'hostels/$hostelId/guests',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Guests screen — day 5')),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _LiveCountCard(
                  icon: Icons.receipt_long,
                  title: 'Invoices & Payments',
                  subtitle: 'Unpaid this month',
                  // Count only unpaid invoices — more useful than total
                  collectionPath: 'hostels/$hostelId/invoices',
                  whereField: 'status',
                  whereEqualTo: 'pending',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invoices — week 2')),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HostelHeader extends StatelessWidget {
  final String name;
  final String city;
  const _HostelHeader({required this.name, required this.city});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              child: Icon(Icons.home_work, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleLarge),
                  Text(city, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrialBanner extends StatelessWidget {
  final String status;
  final DateTime? trialEnd;
  const _TrialBanner({required this.status, required this.trialEnd});

  @override
  Widget build(BuildContext context) {
    if (status != 'trial' || trialEnd == null) return const SizedBox.shrink();
    final daysLeft = trialEnd!.difference(DateTime.now()).inDays;

    // Turn red/urgent when 3 days or fewer remain
    final isUrgent = daysLeft <= 3;
    final bgColor = isUrgent ? Colors.red.shade100 : Colors.amber.shade100;
    final iconColor = isUrgent ? Colors.red.shade900 : Colors.brown;
    final textColor = isUrgent ? Colors.red.shade900 : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isUrgent ? Icons.warning_amber : Icons.info_outline,
            color: iconColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isUrgent
                  ? 'Trial ends in $daysLeft day${daysLeft == 1 ? '' : 's'} — subscribe soon'
                  : 'Free trial: $daysLeft days left',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



// Big hero card showing the vacant-beds count. Reads from the rooms collection
// and sums the `totalBeds - occupiedBeds` of every room in real time.
//
// Since we have no rooms yet, this shows "0 / 0". Day 3 makes it come alive.
class _VacantBedsCard extends StatelessWidget {
  final String hostelId;
  const _VacantBedsCard({required this.hostelId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hostels')
          .doc(hostelId)
          .collection('rooms')
          .snapshots(),
      builder: (context, snapshot) {
        int totalBeds = 0;
        int occupiedBeds = 0;

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            totalBeds += (data['totalBeds'] as num?)?.toInt() ?? 0;
            occupiedBeds += (data['occupiedBeds'] as num?)?.toInt() ?? 0;
          }
        }
        final vacant = totalBeds - occupiedBeds;

        return Card(
          color: Colors.teal.shade50,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vacant beds',
                      style: TextStyle(fontSize: 16, color: Colors.teal),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$vacant',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: Colors.teal.shade900,
                      ),
                    ),
                    Text(
                      'out of $totalBeds total',
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.hotel, size: 40, color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Card that shows a live count badge next to its title.
// Optionally filters by a field (used for "unpaid invoices").
class _LiveCountCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String collectionPath;
  final String? whereField;
  final String? whereEqualTo;
  final VoidCallback onTap;

  const _LiveCountCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.collectionPath,
    this.whereField,
    this.whereEqualTo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection(collectionPath);
    if (whereField != null && whereEqualTo != null) {
      query = query.where(whereField!, isEqualTo: whereEqualTo);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;

        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(icon)),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(subtitle),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.teal.shade900,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: onTap,
          ),
        );
      },
    );
  }
}
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
      // Watch the hostel doc live — name updates instantly if edited
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
                const SizedBox(height: 24),

                // Three placeholder cards — we wire them up days 3-7
                _DashCard(
                  icon: Icons.bed,
                  title: 'Rooms',
                  subtitle: 'Add and manage rooms',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming day 3')),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _DashCard(
                  icon: Icons.people,
                  title: 'Guests',
                  subtitle: 'Add and manage tenants',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming day 5')),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _DashCard(
                  icon: Icons.receipt_long,
                  title: 'Invoices & Payments',
                  subtitle: 'Track rent collection',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming week 2')),
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

// Internal widgets kept in the same file for now — small enough to live here.
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.brown),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Free trial: $daysLeft days left',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _DashCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
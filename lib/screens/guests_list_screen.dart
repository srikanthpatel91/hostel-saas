import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';
import 'add_guest_screen.dart';
import 'guest_detail_screen.dart';

class GuestsListScreen extends StatelessWidget {
  final String hostelId;
  const GuestsListScreen({super.key, required this.hostelId});

  @override
  Widget build(BuildContext context) {
    final hostelService = HostelService();

    return Scaffold(
      appBar: AppBar(title: const Text('Guests')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddGuestScreen(hostelId: hostelId),
            ),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add guest'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: hostelService.watchGuests(hostelId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return const _EmptyState();

          // Split into active and exited for clarity
          final active = docs.where((d) => d.data()['isActive'] == true).toList();
          final exited = docs.where((d) => d.data()['isActive'] != true).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (active.isNotEmpty) ...[
                _SectionHeader(label: 'Current tenants', count: active.length),
                ...active.map((d) => _GuestCard(
                      hostelId: hostelId,
                      guestId: d.id,
                      data: d.data(),
                    )),
                const SizedBox(height: 16),
              ],
              if (exited.isNotEmpty) ...[
                _SectionHeader(label: 'Exited', count: exited.length),
                ...exited.map((d) => _GuestCard(
                      hostelId: hostelId,
                      guestId: d.id,
                      data: d.data(),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No tenants yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add guest" to add your first tenant.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  final String hostelId;
  final String guestId;
  final Map<String, dynamic> data;

  const _GuestCard({
    required this.hostelId,
    required this.guestId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? '';
    final phone = data['phone'] as String? ?? '';
    final roomNumber = data['roomNumber'] as String? ?? '';
    final isActive = data['isActive'] == true;
    final rent = (data['rentAmount'] as num?)?.toInt() ?? 0;
    final joinedAt = (data['joinedAt'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isActive ? Colors.teal.shade100 : Colors.grey.shade300,
          child: Text(
            name.isEmpty ? '?' : name[0].toUpperCase(),
            style: TextStyle(
              color: isActive ? Colors.teal.shade900 : Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room $roomNumber  •  $phone'),
            if (joinedAt != null)
              Text(
                'Joined ${_formatDate(joinedAt)}  •  ₹$rent/mo',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: !isActive
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Exited',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              )
            : const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GuestDetailScreen(
                hostelId: hostelId,
                guestId: guestId,
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
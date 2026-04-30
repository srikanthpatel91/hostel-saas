import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';
import 'add_guest_screen.dart';
import 'guest_detail_screen.dart';

enum _Filter { all, active, exited }

class GuestsListScreen extends StatefulWidget {
  final String hostelId;
  const GuestsListScreen({super.key, required this.hostelId});

  @override
  State<GuestsListScreen> createState() => _GuestsListScreenState();
}

class _GuestsListScreenState extends State<GuestsListScreen> {
  final _searchCtrl = TextEditingController();
  _Filter _filter = _Filter.active;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => setState(() => _searchQuery = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guests'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, room...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true,
                  ),
                ),
              ),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: _Filter.values.map((f) {
                    final label = switch (f) {
                      _Filter.all => 'All',
                      _Filter.active => 'Active',
                      _Filter.exited => 'Exited',
                    };
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(label),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => AddGuestScreen(hostelId: widget.hostelId)),
        ),
        icon: const Icon(Icons.person_add),
        label: const Text('Add guest'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: HostelService().watchGuests(widget.hostelId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allDocs = snapshot.data?.docs ?? [];

          // Apply active/exited filter
          final filtered = allDocs.where((d) {
            final isActive = d.data()['isActive'] == true;
            return switch (_filter) {
              _Filter.all => true,
              _Filter.active => isActive,
              _Filter.exited => !isActive,
            };
          }).toList();

          // Apply search filter
          final searched = _searchQuery.isEmpty
              ? filtered
              : filtered.where((d) {
                  final data = d.data();
                  final name =
                      (data['name'] as String? ?? '').toLowerCase();
                  final phone =
                      (data['phone'] as String? ?? '').toLowerCase();
                  final room =
                      (data['roomNumber'] as String? ?? '').toLowerCase();
                  return name.contains(_searchQuery) ||
                      phone.contains(_searchQuery) ||
                      room.contains(_searchQuery);
                }).toList();

          if (searched.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off,
                      size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No guests match "$_searchQuery"'
                        : _filter == _Filter.exited
                            ? 'No exited guests'
                            : 'No active guests',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          // Split into active and exited when showing all
          if (_filter == _Filter.all) {
            final active =
                searched.where((d) => d.data()['isActive'] == true).toList();
            final exited =
                searched.where((d) => d.data()['isActive'] != true).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (active.isNotEmpty) ...[
                  _SectionHeader(label: 'Current tenants', count: active.length),
                  ...active.map((d) => _GuestCard(
                      hostelId: widget.hostelId, guestId: d.id, data: d.data())),
                  const SizedBox(height: 16),
                ],
                if (exited.isNotEmpty) ...[
                  _SectionHeader(label: 'Exited', count: exited.length),
                  ...exited.map((d) => _GuestCard(
                      hostelId: widget.hostelId, guestId: d.id, data: d.data())),
                ],
              ],
            );
          }

          // Single section for active or exited filter
          final sectionLabel = _filter == _Filter.active
              ? 'Current tenants'
              : 'Exited guests';
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _SectionHeader(label: sectionLabel, count: searched.length),
              ...searched.map((d) => _GuestCard(
                  hostelId: widget.hostelId, guestId: d.id, data: d.data())),
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
          Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
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
    final exitedAt = (data['exitedAt'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isActive ? Colors.teal.shade100 : Colors.grey.shade200,
          child: Text(
            name.isEmpty ? '?' : name[0].toUpperCase(),
            style: TextStyle(
              color:
                  isActive ? Colors.teal.shade900 : Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room $roomNumber  •  $phone'),
            if (isActive && joinedAt != null)
              Text(
                'Joined ${_fmt(joinedAt)}  •  ₹$rent/mo',
                style: const TextStyle(fontSize: 12),
              )
            else if (!isActive && exitedAt != null)
              Text(
                'Exited ${_fmt(exitedAt)}',
                style: TextStyle(
                    fontSize: 12, color: Colors.red.shade400),
              )
            else if (!isActive && joinedAt != null)
              Text('Joined ${_fmt(joinedAt)}',
                  style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: !isActive
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Exited',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700)),
              )
            : const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GuestDetailScreen(
              hostelId: hostelId,
              guestId: guestId,
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

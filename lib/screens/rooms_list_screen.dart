import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';
import '../widgets/plan_limit_banner.dart';
import 'add_room_screen.dart';
import 'edit_room_screen.dart';
import 'subscription_screen.dart';

class RoomsListScreen extends StatelessWidget {
  final String hostelId;
  const RoomsListScreen({super.key, required this.hostelId});

  static const _basicRoomLimit = 50;

  Future<bool> _canAddRoom(BuildContext context, int currentCount) async {
    final snap = await FirebaseFirestore.instance
        .collection('hostels')
        .doc(hostelId)
        .get();
    final sub = snap.data()?['subscription'] as Map<String, dynamic>? ?? {};
    final plan = (sub['plan'] as String? ?? 'basic').toLowerCase();

    if (plan != 'basic') return true;
    if (currentCount < _basicRoomLimit) return true;

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.lock_outline, color: Colors.red, size: 36),
          title: const Text('Room limit reached'),
          content: const Text(
              'Basic plan allows up to $_basicRoomLimit rooms.\n'
              'Upgrade to Pro for unlimited rooms.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Not now')),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SubscriptionScreen(hostelId: hostelId),
                ));
              },
              child: const Text('Upgrade'),
            ),
          ],
        ),
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final hostelService = HostelService();

    return Scaffold(
      appBar: AppBar(title: const Text('Rooms')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: hostelService.watchRooms(hostelId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          final count = docs.length;

          if (docs.isEmpty) {
            return const _EmptyState();
          }

          return Column(
            children: [
              PlanLimitBanner(
                  hostelId: hostelId, resource: 'rooms', current: count),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: count,
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    return _RoomCard(
                      hostelId: hostelId,
                      roomId: doc.id,
                      data: doc.data(),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: hostelService.watchRooms(hostelId),
        builder: (context, snapshot) {
          final count = snapshot.data?.docs.length ?? 0;
          return FloatingActionButton.extended(
            onPressed: () async {
              final ok = await _canAddRoom(context, count);
              if (ok && context.mounted) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AddRoomScreen(hostelId: hostelId),
                ));
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add room'),
          );
        },
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
            Icon(Icons.bed_outlined, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No rooms yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add room" to create your first room.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final String hostelId;
  final String roomId;
  final Map<String, dynamic> data;

  const _RoomCard({
    required this.hostelId,
    required this.roomId,
    required this.data,
  });

  void _openEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditRoomScreen(
          hostelId: hostelId,
          roomId: roomId,
          initialData: data,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomNumber = data['roomNumber'] as String? ?? '';
    final type = data['type'] as String? ?? '';
    final totalBeds = (data['totalBeds'] as num?)?.toInt() ?? 0;
    final occupiedBeds = (data['occupiedBeds'] as num?)?.toInt() ?? 0;
    final rent = (data['rentAmount'] as num?)?.toInt() ?? 0;
    final floor = (data['floor'] as num?)?.toInt();
    final vacantBeds = totalBeds - occupiedBeds;
    final underMaintenance = data['underMaintenance'] == true;

    // Status color and label — maintenance takes priority
    final Color statusColor;
    final String statusLabel;
    if (underMaintenance) {
      statusColor = Colors.brown;
      statusLabel = 'Maintenance';
    } else if (occupiedBeds == 0) {
      statusColor = Colors.green;
      statusLabel = 'Vacant';
    } else if (occupiedBeds >= totalBeds) {
      statusColor = Colors.red;
      statusLabel = 'Full';
    } else {
      statusColor = Colors.orange;
      statusLabel = 'Partial';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openEdit(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          floor == null
                              ? 'Room $roomNumber'
                              : 'Room $roomNumber  •  Floor ${floor == 0 ? 'G' : floor}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              _prettyType(type),
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            if (data['hasAC'] == true) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text(
                                  'AC',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (action) async {
                      if (action == 'edit') {
                        _openEdit(context);
                      } else if (action == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete room?'),
                            content: Text(
                              'Room $roomNumber will be permanently deleted.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await HostelService().deleteRoom(
                            hostelId: hostelId,
                            roomId: roomId,
                          );
                        }
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit room'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete room'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.bed, size: 18, color: Colors.grey.shade700),
                  const SizedBox(width: 4),
                  Text(
                    '$occupiedBeds / $totalBeds beds occupied  •  $vacantBeds vacant',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    '₹$rent / bed',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Quick +/- controls — disabled while in maintenance
              Row(
                children: [
                  IconButton.outlined(
                    onPressed: (underMaintenance || occupiedBeds == 0)
                        ? null
                        : () => HostelService().updateRoomOccupancy(
                              hostelId: hostelId,
                              roomId: roomId,
                              occupiedBeds: occupiedBeds - 1,
                              totalBeds: totalBeds,
                            ),
                    icon: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$occupiedBeds',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: (underMaintenance || occupiedBeds >= totalBeds)
                        ? null
                        : () => HostelService().updateRoomOccupancy(
                              hostelId: hostelId,
                              roomId: roomId,
                              occupiedBeds: occupiedBeds + 1,
                              totalBeds: totalBeds,
                            ),
                    icon: const Icon(Icons.add),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    underMaintenance
                        ? 'Locked while in maintenance'
                        : 'Mark occupied beds',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _prettyType(String t) {
  switch (t) {
    case 'dormitory':
      return 'Dormitory / Hall';
    default:
      return t.isEmpty ? '' : t[0].toUpperCase() + t.substring(1);
  }
}
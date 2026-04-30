import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

// Static service catalogue — owner can't edit these for MVP.
// Each entry: id, name, category, price label, duration, icon.
const _kServices = [
  {
    'id': 'laundry',
    'name': 'Laundry Wash & Fold',
    'category': 'Laundry',
    'price': '₹50/kg',
    'duration': '4 Hours',
    'icon': 'laundry',
    'popular': true,
  },
  {
    'id': 'bike_wash',
    'name': 'Eco Bike Wash',
    'category': 'Automotive',
    'price': '₹120',
    'duration': '45 Mins',
    'icon': 'bike',
    'popular': false,
  },
  {
    'id': 'water',
    'name': 'Water Refill (20L)',
    'category': 'Utilities',
    'price': '₹35',
    'duration': '15 Mins',
    'icon': 'water',
    'popular': false,
  },
  {
    'id': 'cleaning',
    'name': 'Deep Cleaning',
    'category': 'Housekeeping',
    'price': '₹299',
    'duration': '2 Hours',
    'icon': 'cleaning',
    'popular': false,
  },
];

const _kSlots = [
  {'label': '09:00', 'period': 'MORNING'},
  {'label': '10:30', 'period': 'MORNING'},
  {'label': '12:30', 'period': 'AFTERNOON'},
  {'label': '14:00', 'period': 'AFTERNOON'},
  {'label': '16:30', 'period': 'EVENING'},
  {'label': '18:00', 'period': 'EVENING'},
];

const _kCategories = [
  'All',
  'Laundry',
  'Housekeeping',
  'Automotive',
  'Utilities',
];

class ServiceMarketplaceScreen extends StatefulWidget {
  final String hostelId;
  final String guestId;
  final String guestName;
  const ServiceMarketplaceScreen({
    super.key,
    required this.hostelId,
    required this.guestId,
    required this.guestName,
  });

  @override
  State<ServiceMarketplaceScreen> createState() =>
      _ServiceMarketplaceScreenState();
}

class _ServiceMarketplaceScreenState extends State<ServiceMarketplaceScreen> {
  String _selectedCategory = 'All';

  List<Map<String, dynamic>> get _filtered => _selectedCategory == 'All'
      ? List<Map<String, dynamic>>.from(_kServices)
      : _kServices
          .where((s) => s['category'] == _selectedCategory)
          .toList()
          .cast<Map<String, dynamic>>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services Market')),
      body: Column(
        children: [
          // Category filter chips
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _kCategories.length,
              separatorBuilder: (_, b) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = _kCategories[i];
                final selected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),
          // Service list + bookings
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Premium Services',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Curated services for your stay at Sanctuary.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  ..._filtered.map((service) => _ServiceCard(
                        service: service,
                        onBook: () => _showBookingSheet(context, service),
                      )),
                  const SizedBox(height: 24),
                  _MyBookingsSection(
                    hostelId: widget.hostelId,
                    guestId: widget.guestId,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingSheet(
      BuildContext context, Map<String, dynamic> service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SlotSelectionSheet(
        hostelId: widget.hostelId,
        guestId: widget.guestId,
        guestName: widget.guestName,
        service: service,
      ),
    );
  }
}

// ── Service card ────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final VoidCallback onBook;
  const _ServiceCard({required this.service, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final isPopular = service['popular'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _icon(service['icon'] as String),
                color: Colors.teal,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          service['name'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                      if (isPopular)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Popular',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.purple.shade700),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 13, color: Colors.black45),
                      const SizedBox(width: 4),
                      Text(
                        service['duration'] as String,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        service['price'] as String,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onBook,
              child: const Text('Book'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icon(String key) {
    switch (key) {
      case 'laundry':
        return Icons.local_laundry_service_outlined;
      case 'bike':
        return Icons.pedal_bike_outlined;
      case 'water':
        return Icons.water_drop_outlined;
      case 'cleaning':
        return Icons.cleaning_services_outlined;
      default:
        return Icons.miscellaneous_services_outlined;
    }
  }
}

// ── Slot selection bottom sheet ─────────────────────────────────────────

class _SlotSelectionSheet extends StatefulWidget {
  final String hostelId;
  final String guestId;
  final String guestName;
  final Map<String, dynamic> service;
  const _SlotSelectionSheet({
    required this.hostelId,
    required this.guestId,
    required this.guestName,
    required this.service,
  });

  @override
  State<_SlotSelectionSheet> createState() => _SlotSelectionSheetState();
}

class _SlotSelectionSheetState extends State<_SlotSelectionSheet> {
  bool _today = true;
  String? _selectedSlot;
  bool _booking = false;

  String get _bookingDate {
    final d =
        DateTime.now().add(_today ? Duration.zero : const Duration(days: 1));
    return '${d.day}/${d.month}/${d.year}';
  }

  Future<void> _confirm() async {
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pick a time slot')));
      return;
    }
    setState(() => _booking = true);
    try {
      await HostelService().bookService(
        hostelId: widget.hostelId,
        guestId: widget.guestId,
        guestName: widget.guestName,
        serviceName: widget.service['name'] as String,
        category: widget.service['category'] as String,
        price: widget.service['price'] as String,
        slot: '$_selectedSlot, $_bookingDate',
        bookingDate: _bookingDate,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${widget.service['name']} booked for $_selectedSlot on $_bookingDate'),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.service['name'] as String,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${widget.service['duration']}  •  ${widget.service['price']}',
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              // Today / Tomorrow toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _DayToggle(
                      label: 'Today',
                      selected: _today,
                      onTap: () => setState(() {
                        _today = true;
                        _selectedSlot = null;
                      }),
                    ),
                    _DayToggle(
                      label: 'Tomorrow',
                      selected: !_today,
                      onTap: () => setState(() {
                        _today = false;
                        _selectedSlot = null;
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Select a time slot',
              style:
                  TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _kSlots.map((slot) {
              final label = slot['label']!;
              final period = slot['period']!;
              final selected = _selectedSlot == label;
              return GestureDetector(
                onTap: () => setState(() => _selectedSlot = label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? Colors.teal : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: selected
                        ? null
                        : Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        period,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? Colors.white70
                              : Colors.black45,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color:
                              selected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: _booking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline),
            label: Text(_booking ? 'Confirming…' : 'Confirm Schedule'),
            onPressed: _booking ? null : _confirm,
          ),
        ],
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DayToggle(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }
}

// ── My bookings section (tenant's past/active bookings) ─────────────────

class _MyBookingsSection extends StatelessWidget {
  final String hostelId;
  final String guestId;
  const _MyBookingsSection(
      {required this.hostelId, required this.guestId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: HostelService().watchMyServiceBookings(
          hostelId: hostelId, guestId: guestId),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'My Bookings',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ...docs.map((doc) {
              final d = doc.data();
              final name = d['serviceName'] as String? ?? '';
              final slot = d['slot'] as String? ?? '';
              final price = d['price'] as String? ?? '';
              final status = d['status'] as String? ?? 'pending';

              final statusColor = switch (status) {
                'confirmed' => Colors.teal,
                'completed' => Colors.green,
                'cancelled' => Colors.red,
                _ => Colors.orange,
              };

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.miscellaneous_services_outlined),
                  ),
                  title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(slot,
                      style: const TextStyle(fontSize: 12)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(price,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status[0].toUpperCase() + status.substring(1),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusColor),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

/// QR Code Entry System.
/// - Guest: shows their personal QR code (hostelId + guestId + name).
/// - Owner/Staff: enter guest ID or scan to verify entry.
class QrEntryScreen extends StatefulWidget {
  final String hostelId;
  final String? guestId; // if provided, show guest QR
  const QrEntryScreen({super.key, required this.hostelId, this.guestId});

  @override
  State<QrEntryScreen> createState() => _QrEntryScreenState();
}

class _QrEntryScreenState extends State<QrEntryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    // If guestId provided, only show guest QR
    _tabs = TabController(length: widget.guestId != null ? 1 : 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.guestId != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Entry QR Code'), centerTitle: true),
        body: _GuestQrView(hostelId: widget.hostelId, guestId: widget.guestId!),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Entry System'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Verify Guest'), Tab(text: 'Entry Log')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _VerifyTab(hostelId: widget.hostelId),
          _EntryLogTab(hostelId: widget.hostelId),
        ],
      ),
    );
  }
}

// ─── Guest QR View ─────────────────────────────────────────────────────────

class _GuestQrView extends StatelessWidget {
  final String hostelId, guestId;
  const _GuestQrView({required this.hostelId, required this.guestId});

  @override
  Widget build(BuildContext context) {
    final qrData = '$hostelId|$guestId';

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('hostels').doc(hostelId)
          .collection('guests').doc(guestId)
          .get(),
      builder: (context, snap) {
        final name = snap.data?.data()?['name'] as String? ?? 'Guest';
        final room = snap.data?.data()?['roomNumber'] as String? ?? '';

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                if (room.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Room $room', style: const TextStyle(fontSize: 15, color: Colors.grey)),
                ],
                const SizedBox(height: 24),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 220,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Show this QR code at hostel entry',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ID: $guestId',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Verify Tab (Staff/Owner) ───────────────────────────────────────────────

class _VerifyTab extends StatefulWidget {
  final String hostelId;
  const _VerifyTab({required this.hostelId});

  @override
  State<_VerifyTab> createState() => _VerifyTabState();
}

class _VerifyTabState extends State<_VerifyTab> {
  final _ctrl = TextEditingController();
  Map<String, dynamic>? _guestData;
  bool _loading = false;
  String? _error;

  Future<void> _verify() async {
    setState(() { _loading = true; _error = null; _guestData = null; });
    try {
      final input = _ctrl.text.trim();
      // Supports both plain guestId and QR format "hostelId|guestId"
      final guestId = input.contains('|') ? input.split('|')[1] : input;

      final doc = await FirebaseFirestore.instance
          .collection('hostels').doc(widget.hostelId)
          .collection('guests').doc(guestId)
          .get();

      if (!doc.exists) {
        setState(() { _error = 'Guest not found'; _loading = false; });
        return;
      }

      final data = doc.data()!;
      if (data['status'] != 'active') {
        setState(() { _error = 'Guest is not active (${data['status']})'; _loading = false; });
        return;
      }

      // Log entry
      await FirebaseFirestore.instance
          .collection('hostels').doc(widget.hostelId)
          .collection('entryLog')
          .add({
        'guestId': guestId,
        'guestName': data['name'] ?? '',
        'roomNumber': data['roomNumber'] ?? '',
        'entryAt': FieldValue.serverTimestamp(),
        'method': 'manual',
      });

      setState(() { _guestData = data; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Error: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          const Text(
            'Enter guest ID or paste QR code data to verify entry',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              labelText: 'Guest ID or QR Code',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.qr_code_scanner),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _verify,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.verified_outlined),
              label: const Text('Verify Entry'),
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Card(
              color: Colors.red.withAlpha(20),
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ),
          if (_guestData != null)
            Card(
              color: Colors.green.withAlpha(20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.green.withAlpha(80)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, size: 48, color: Colors.green),
                    const SizedBox(height: 8),
                    Text(
                      'Entry Verified ✓',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    _InfoRow('Name', _guestData!['name'] ?? ''),
                    _InfoRow('Room', _guestData!['roomNumber'] ?? ''),
                    _InfoRow('Status', _guestData!['status'] ?? ''),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Entry Log ─────────────────────────────────────────────────────────────

class _EntryLogTab extends StatelessWidget {
  final String hostelId;
  const _EntryLogTab({required this.hostelId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hostels').doc(hostelId)
          .collection('entryLog')
          .orderBy('entryAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No entry log yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, idx) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final entryAt = (d['entryAt'] as Timestamp?)?.toDate();
            return ListTile(
              dense: true,
              leading: const CircleAvatar(radius: 18, child: Icon(Icons.login, size: 16)),
              title: Text(d['guestName'] as String? ?? ''),
              subtitle: Text('Room ${d['roomNumber'] ?? ''}'),
              trailing: entryAt != null
                  ? Text(DateFormat('hh:mm a\ndd MMM').format(entryAt),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11))
                  : null,
            );
          },
        );
      },
    );
  }
}

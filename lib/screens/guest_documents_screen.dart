import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

class GuestDocumentsScreen extends StatelessWidget {
  final String hostelId;
  final String guestId;
  final String guestName;
  const GuestDocumentsScreen({
    super.key,
    required this.hostelId,
    required this.guestId,
    required this.guestName,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('$guestName — Documents')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: HostelService()
            .watchGuestDocuments(hostelId: hostelId, guestId: guestId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open_outlined,
                      size: 56,
                      color: cs.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text('No documents uploaded yet',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.5))),
                  const SizedBox(height: 6),
                  Text('Ask the tenant to upload via their app',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (ctx, i) =>
                _DocTile(doc: docs[i], hostelId: hostelId, guestId: guestId),
          );
        },
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String hostelId;
  final String guestId;
  const _DocTile(
      {required this.doc, required this.hostelId, required this.guestId});

  static const _typeLabels = {
    'aadhaar_front': 'Aadhaar Front',
    'aadhaar_back': 'Aadhaar Back',
    'police_verification': 'Police Verification',
    'photo': 'Passport Photo',
    'other': 'Other',
  };

  static const _typeIcons = {
    'aadhaar_front': Icons.credit_card,
    'aadhaar_back': Icons.credit_card_outlined,
    'police_verification': Icons.local_police_outlined,
    'photo': Icons.face_outlined,
    'other': Icons.attach_file_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final type = data['type'] as String? ?? 'other';
    final label = _typeLabels[type] ?? type;
    final icon = _typeIcons[type] ?? Icons.insert_drive_file_outlined;
    final fileName = data['fileName'] as String? ?? 'file';
    final uploadedAt = (data['uploadedAt'] as Timestamp?)?.toDate();
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.secondaryContainer,
          child: Icon(icon, size: 20, color: cs.onSecondaryContainer),
        ),
        title: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fileName,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis),
            if (uploadedAt != null)
              Text(
                'Uploaded ${_fmtDate(uploadedAt)}',
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5)),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.teal, size: 18),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 20),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context, data),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const m = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Future<void> _confirmDelete(
      BuildContext context, Map<String, dynamic> data) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete document?'),
        content: const Text('This will permanently remove the file.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await HostelService().deleteGuestDocument(
        hostelId: hostelId,
        guestId: guestId,
        docId: doc.id,
        downloadUrl: data['downloadUrl'] as String? ?? '',
      );
    }
  }
}

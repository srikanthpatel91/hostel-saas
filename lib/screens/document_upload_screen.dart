import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/hostel_service.dart';
import '../services/storage_service.dart';

class DocumentUploadScreen extends StatefulWidget {
  final String hostelId;
  final String guestId;
  const DocumentUploadScreen(
      {super.key, required this.hostelId, required this.guestId});

  @override
  State<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends State<DocumentUploadScreen> {
  static const _docTypes = [
    _DocType('aadhaar_front', 'Aadhaar Front', Icons.credit_card),
    _DocType('aadhaar_back', 'Aadhaar Back', Icons.credit_card_outlined),
    _DocType('police_verification', 'Police Verification', Icons.local_police_outlined),
    _DocType('photo', 'Passport Photo', Icons.face_outlined),
    _DocType('other', 'Other Document', Icons.attach_file_outlined),
  ];

  final Map<String, bool> _uploading = {};
  final _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Documents')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: cs.onPrimaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Upload a clear photo or scan. Accepted: JPG, PNG. Max 5 MB.',
                    style: TextStyle(
                        fontSize: 13, color: cs.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ..._docTypes.map((dt) => _DocCard(
                docType: dt,
                hostelId: widget.hostelId,
                guestId: widget.guestId,
                uploading: _uploading[dt.key] ?? false,
                onUpload: () => _pick(dt),
              )),
        ],
      ),
    );
  }

  Future<void> _pick(_DocType dt) async {
    final source = await _showSourceSheet();
    if (source == null) return;

    final XFile? xfile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (xfile == null) return;

    setState(() => _uploading[dt.key] = true);
    try {
      final file = File(xfile.path);
      final url = await StorageService().uploadGuestDocument(
        hostelId: widget.hostelId,
        guestId: widget.guestId,
        type: dt.key,
        file: file,
      );
      await HostelService().saveDocumentRecord(
        hostelId: widget.hostelId,
        guestId: widget.guestId,
        type: dt.key,
        downloadUrl: url,
        fileName: xfile.name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${dt.label} uploaded'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading[dt.key] = false);
    }
  }

  Future<ImageSource?> _showSourceSheet() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Doc Card ─────────────────────────────────────────────────────────────────

class _DocCard extends StatelessWidget {
  final _DocType docType;
  final String hostelId;
  final String guestId;
  final bool uploading;
  final VoidCallback onUpload;

  const _DocCard({
    required this.docType,
    required this.hostelId,
    required this.guestId,
    required this.uploading,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: cs.secondaryContainer,
                  child: Icon(docType.icon,
                      size: 20, color: cs.onSecondaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(docType.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                if (uploading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload_outlined, size: 16),
                    label: const Text('Upload'),
                    onPressed: onUpload,
                  ),
              ],
            ),
            // Show previously uploaded files for this type
            _UploadedList(
                hostelId: hostelId,
                guestId: guestId,
                typeKey: docType.key),
          ],
        ),
      ),
    );
  }
}

// ─── Previously uploaded list ─────────────────────────────────────────────────

class _UploadedList extends StatelessWidget {
  final String hostelId;
  final String guestId;
  final String typeKey;
  const _UploadedList(
      {required this.hostelId,
      required this.guestId,
      required this.typeKey});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: HostelService()
          .watchGuestDocuments(hostelId: hostelId, guestId: guestId),
      builder: (ctx, snap) {
        final docs = (snap.data?.docs ?? [])
            .where((d) => d['type'] == typeKey)
            .toList();
        if (docs.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: docs.map((d) {
              final name = d['fileName'] as String? ?? 'file';
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle,
                    color: Colors.teal, size: 18),
                title: Text(name,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 18),
                  tooltip: 'Delete',
                  onPressed: () => _delete(context, d.id,
                      d['downloadUrl'] as String? ?? ''),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _delete(
      BuildContext context, String docId, String url) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete document?'),
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
          docId: docId,
          downloadUrl: url);
    }
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────

class _DocType {
  final String key;
  final String label;
  final IconData icon;
  const _DocType(this.key, this.label, this.icon);
}

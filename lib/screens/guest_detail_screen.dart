import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../services/hostel_service.dart';
import 'edit_guest_screen.dart';

class GuestDetailScreen extends StatelessWidget {
  final String hostelId;
  final String guestId;

  const GuestDetailScreen({
    super.key,
    required this.hostelId,
    required this.guestId,
  });

  Future<void> _confirmExit(BuildContext context, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as exited?'),
        content: Text(
          '$name will be moved to the Exited list. Their bed will become vacant again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark exited'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await HostelService().markGuestExited(
        hostelId: hostelId,
        guestId: guestId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guest marked as exited'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: HostelService().watchGuest(
          hostelId: hostelId,
          guestId: guestId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Scaffold(
              body: Center(child: Text('Guest not found')),
            );
          }

          final data = snapshot.data!.data()!;
          final name = data['name'] as String? ?? '';
          final phone = data['phone'] as String? ?? '';
          final roomNumber = data['roomNumber'] as String? ?? '';
          final isActive = data['isActive'] == true;
          final rent = (data['rentAmount'] as num?)?.toInt() ?? 0;
          final deposit = (data['depositAmount'] as num?)?.toInt() ?? 0;
          final joinedAt = (data['joinedAt'] as Timestamp?)?.toDate();
          final exitedAt = (data['exitedAt'] as Timestamp?)?.toDate();
          final notes = data['notes'] as String? ?? '';
          final dob = (data['dateOfBirth'] as Timestamp?)?.toDate();
          final gender = data['gender'] as String? ?? '';

          return Scaffold(
            appBar: AppBar(
              title: const Text('Guest details'),
              actions: [
                if (isActive)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit guest',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EditGuestScreen(
                            hostelId: hostelId,
                            guestId: guestId,
                            initialData: data,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: isActive
                                ? Colors.teal.shade100
                                : Colors.grey.shade300,
                            child: Text(
                              name.isEmpty ? '?' : name[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: isActive
                                    ? Colors.teal.shade900
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(phone,
                                    style: TextStyle(
                                        color: Colors.grey.shade700)),
                                if (!isActive) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Exited',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        _InfoRow(label: 'Room', value: 'Room $roomNumber'),
                        _InfoRow(label: 'Phone', value: phone),
                        _InfoRow(
                            label: 'Joined',
                            value: joinedAt != null ? _formatDate(joinedAt) : '-'),
                        if (exitedAt != null)
                          _InfoRow(label: 'Exited', value: _formatDate(exitedAt)),
                        if (dob != null)
                          _InfoRow(label: 'Date of birth', value: _formatDate(dob)),
                        if (gender.isNotEmpty)
                          _InfoRow(
                              label: 'Gender',
                              value: gender[0].toUpperCase() + gender.substring(1)),
                        _InfoRow(label: 'Monthly rent', value: '₹$rent'),
                        _InfoRow(
                            label: 'Security deposit',
                            value: '₹$deposit',
                            isLast: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Receipt alert — shown when tenant uploaded payment proof
                  _ReceiptAlert(hostelId: hostelId, guestId: guestId),
                  const SizedBox(height: 16),
                  if (notes.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Notes',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(notes),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _GuestDocumentsSection(
                    hostelId: hostelId,
                    guestId: guestId,
                  ),
                  const SizedBox(height: 12),
                  _MealPlanSection(
                    hostelId: hostelId,
                    guestId: guestId,
                    currentPlanId: data['mealPlanId'] as String?,
                    currentPlanName: data['mealPlanName'] as String?,
                    currentPlanPrice: (data['mealPlanPrice'] as num?)?.toInt(),
                    isActive: isActive,
                  ),
                  const SizedBox(height: 12),
                  if (isActive)
                    FilledButton.icon(
                      onPressed: () => _confirmExit(context, name),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Mark as exited'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Documents Section ────────────────────────────────────────────────────────

class _GuestDocumentsSection extends StatefulWidget {
  final String hostelId;
  final String guestId;
  const _GuestDocumentsSection(
      {required this.hostelId, required this.guestId});

  @override
  State<_GuestDocumentsSection> createState() => _GuestDocumentsSectionState();
}

class _GuestDocumentsSectionState extends State<_GuestDocumentsSection> {
  static const _docTypes = [
    'Aadhaar Card',
    'PAN Card',
    'Passport',
    'Driving License',
    'Rental Agreement',
    'Other',
  ];

  bool _uploading = false;
  double? _uploadProgress;

  Future<void> _pickAndUpload(String type) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
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
              title: const Text('Pick from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final file = await picker.pickImage(
        source: source, imageQuality: 85, maxWidth: 1800);
    if (file == null) return;

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last;
      final fileName =
          '${type.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = FirebaseStorage.instance
          .ref()
          .child('hostels/${widget.hostelId}/guests/${widget.guestId}/$fileName');

      final task = ref.putData(
          bytes, SettableMetadata(contentType: 'image/jpeg'));
      task.snapshotEvents.listen((s) {
        if (mounted && s.totalBytes > 0) {
          setState(
              () => _uploadProgress = s.bytesTransferred / s.totalBytes);
        }
      });
      await task;
      final url = await ref.getDownloadURL();
      await HostelService().saveDocumentRecord(
        hostelId: widget.hostelId,
        guestId: widget.guestId,
        type: type,
        downloadUrl: url,
        fileName: fileName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Document uploaded'), backgroundColor: Colors.teal),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() {_uploading = false; _uploadProgress = null;});
    }
  }

  void _showTypePickerThenUpload() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Select document type',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            ..._docTypes.map((type) => ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(type),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUpload(type);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(String docId, String url) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete document?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    await HostelService().deleteGuestDocument(
      hostelId: widget.hostelId,
      guestId: widget.guestId,
      docId: docId,
      downloadUrl: url,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.folder_outlined, size: 18),
                const SizedBox(width: 8),
                const Text('Documents',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                if (_uploading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: _uploadProgress),
                  )
                else
                  TextButton.icon(
                    icon: const Icon(Icons.upload_outlined, size: 16),
                    label: const Text('Upload'),
                    onPressed: _showTypePickerThenUpload,
                  ),
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: HostelService().watchGuestDocuments(
                hostelId: widget.hostelId, guestId: widget.guestId),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Text(
                    'No documents uploaded yet',
                    style: TextStyle(
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                        fontSize: 13),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                itemCount: docs.length,
                separatorBuilder: (a, b) => const SizedBox(height: 4),
                itemBuilder: (ctx, i) {
                  final d = docs[i].data();
                  final type = d['type'] as String? ?? 'Document';
                  final fileName = d['fileName'] as String? ?? '';
                  final url = d['downloadUrl'] as String? ?? '';
                  final uploadedAt =
                      (d['uploadedAt'] as Timestamp?)?.toDate();
                  return ListTile(
                    dense: true,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: url.isNotEmpty
                          ? Image.network(url,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => const Icon(
                                  Icons.broken_image_outlined,
                                  size: 32))
                          : const Icon(Icons.description_outlined, size: 32),
                    ),
                    title: Text(type,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      uploadedAt != null
                          ? '${uploadedAt.day}/${uploadedAt.month}/${uploadedAt.year}'
                          : fileName,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.open_in_new, size: 18),
                          tooltip: 'View',
                          onPressed: () => _viewDocument(context, url, type),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () => _delete(docs[i].id, url),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _viewDocument(BuildContext context, String url, String title) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: InteractiveViewer(
          child: Center(
            child: Image.network(
              url,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
              errorBuilder: (c, e, s) => const Center(
                  child: Text('Could not load image')),
            ),
          ),
        ),
      ),
    ));
  }
}

// ─── Info Row ──────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─── Meal Plan Section ────────────────────────────────────────────────────────

class _MealPlanSection extends StatelessWidget {
  final String hostelId;
  final String guestId;
  final String? currentPlanId;
  final String? currentPlanName;
  final int? currentPlanPrice;
  final bool isActive;

  const _MealPlanSection({
    required this.hostelId,
    required this.guestId,
    required this.currentPlanId,
    required this.currentPlanName,
    required this.currentPlanPrice,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasPlan = currentPlanId != null && currentPlanName != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant_outlined, size: 18),
                const SizedBox(width: 8),
                const Text('Meal Plan',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                if (isActive)
                  TextButton.icon(
                    icon: Icon(
                        hasPlan ? Icons.swap_horiz : Icons.add, size: 16),
                    label: Text(hasPlan ? 'Change' : 'Assign'),
                    onPressed: () => _showPlanPicker(context),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!hasPlan)
              Text('No meal plan assigned',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                      fontSize: 13))
            else
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(currentPlanName!,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onPrimaryContainer)),
                  ),
                  if (currentPlanPrice != null) ...[
                    const SizedBox(width: 10),
                    Text('₹$currentPlanPrice',
                        style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                  const Spacer(),
                  if (isActive)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18,
                          color: Colors.red),
                      tooltip: 'Remove plan',
                      onPressed: () => _removePlan(context),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPlanPicker(BuildContext context) async {
    final snap = await HostelService().watchMealPlans(hostelId).first;
    final plans = snap.docs;
    if (!context.mounted) return;
    if (plans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No meal plans created yet. Add plans first.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlanPickerSheet(
        hostelId: hostelId,
        guestId: guestId,
        plans: plans,
      ),
    );
  }

  Future<void> _removePlan(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove meal plan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await HostelService()
          .removeGuestMealPlan(hostelId: hostelId, guestId: guestId);
    }
  }
}

class _PlanPickerSheet extends StatefulWidget {
  final String hostelId;
  final String guestId;
  final List<dynamic> plans;
  const _PlanPickerSheet(
      {required this.hostelId,
      required this.guestId,
      required this.plans});

  @override
  State<_PlanPickerSheet> createState() => _PlanPickerSheetState();
}

class _PlanPickerSheetState extends State<_PlanPickerSheet> {
  String _cycle = 'monthly';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assign Meal Plan',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'weekly',
                  label: Text('Weekly'),
                  icon: Icon(Icons.view_week_outlined, size: 16)),
              ButtonSegment(
                  value: 'monthly',
                  label: Text('Monthly'),
                  icon: Icon(Icons.calendar_month_outlined, size: 16)),
            ],
            selected: {_cycle},
            onSelectionChanged: (s) => setState(() => _cycle = s.first),
          ),
          const SizedBox(height: 12),
          ...widget.plans.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] as String? ?? '';
            final price = _cycle == 'weekly'
                ? (data['weeklyPrice'] as num?)?.toInt() ?? 0
                : (data['monthlyPrice'] as num?)?.toInt() ?? 0;
            return ListTile(
              title: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: Text('₹$price',
                  style: TextStyle(
                      color: cs.primary, fontWeight: FontWeight.w600)),
              onTap: () async {
                await HostelService().assignGuestMealPlan(
                  hostelId: widget.hostelId,
                  guestId: widget.guestId,
                  planId: doc.id,
                  planName: name,
                  planPrice: price,
                );
                if (context.mounted) Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }
}

// ─── Receipt Alert ────────────────────────────────────────────────────────────
// Shown on guest detail when the tenant has uploaded a payment proof
// but the invoice is still pending — prompts owner to review and mark paid.

class _ReceiptAlert extends StatelessWidget {
  final String hostelId;
  final String guestId;
  const _ReceiptAlert({required this.hostelId, required this.guestId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('hostels')
          .doc(hostelId)
          .collection('invoices')
          .where('guestId', isEqualTo: guestId)
          .where('status', whereIn: ['pending', 'overdue'])
          .snapshots(),
      builder: (_, snap) {
        final withReceipt = (snap.data?.docs ?? [])
            .where((d) => d.data()['receiptUrl'] != null)
            .toList();
        if (withReceipt.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.attach_file, color: Colors.teal, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment proof uploaded',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: Colors.teal)),
                    Text(
                      '${withReceipt.length} invoice${withReceipt.length == 1 ? '' : 's'} — review and mark as paid',
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
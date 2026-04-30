import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

class RaiseComplaintScreen extends StatefulWidget {
  final String hostelId;
  final String guestId;
  const RaiseComplaintScreen(
      {super.key, required this.hostelId, required this.guestId});

  @override
  State<RaiseComplaintScreen> createState() => _RaiseComplaintScreenState();
}

class _RaiseComplaintScreenState extends State<RaiseComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  String _category = HostelService.complaintCategories.first;
  bool _saving = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      // Fetch guest name + room to store on the complaint doc
      final guestSnap = await FirebaseFirestore.instance
          .collection('hostels')
          .doc(widget.hostelId)
          .collection('guests')
          .doc(widget.guestId)
          .get();
      final gData = guestSnap.data() ?? {};
      await HostelService().raiseComplaint(
        hostelId: widget.hostelId,
        guestId: widget.guestId,
        guestName: gData['name'] as String? ?? '',
        roomNumber: gData['roomNumber'] as String? ?? '',
        category: _category,
        description: _descCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Complaint submitted'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  IconData _catIcon(String cat) => switch (cat) {
        'Maintenance' => Icons.build,
        'Cleanliness' => Icons.cleaning_services,
        'Noise' => Icons.volume_up,
        'Water' => Icons.water_drop,
        'Electricity' => Icons.bolt,
        'Internet' => Icons.wifi_off,
        'Security' => Icons.security,
        _ => Icons.report_problem,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raise Complaint')),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'We\'ll notify the hostel owner immediately.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),

              // Category grid
              const Text('Category',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: HostelService.complaintCategories.map((cat) {
                  final selected = cat == _category;
                  return FilterChip(
                    avatar: Icon(_catIcon(cat),
                        size: 16,
                        color: selected ? Colors.white : Colors.grey.shade600),
                    label: Text(cat),
                    selected: selected,
                    onSelected: (_) => setState(() => _category = cat),
                    selectedColor: Colors.red.shade400,
                    labelStyle: TextStyle(
                        color: selected ? Colors.white : null,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal),
                    checkmarkColor: Colors.white,
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Describe the issue',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                  hintText: 'E.g. "The bathroom tap has been leaking since yesterday"',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please describe the issue';
                  if (v.trim().length < 10) return 'Too short — add more detail';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                icon: const Icon(Icons.send),
                label: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Submit complaint'),
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

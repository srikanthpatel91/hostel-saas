import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

class HostelSettingsScreen extends StatefulWidget {
  final String hostelId;
  const HostelSettingsScreen({super.key, required this.hostelId});

  @override
  State<HostelSettingsScreen> createState() => _HostelSettingsScreenState();
}

class _HostelSettingsScreenState extends State<HostelSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  bool _gstEnabled = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await FirebaseFirestore.instance
        .collection('hostels')
        .doc(widget.hostelId)
        .get();
    final d = snap.data() ?? {};
    final phone = (d['phone'] as String? ?? '').replaceFirst('+91', '');
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = d['name'] as String? ?? '';
      _addressCtrl.text = d['address'] as String? ?? '';
      _cityCtrl.text = d['city'] as String? ?? '';
      _phoneCtrl.text = phone;
      _gstinCtrl.text = d['gstin'] as String? ?? '';
      _gstEnabled = d['gstEnabled'] == true;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    _gstinCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await HostelService().updateHostelSettings(
        hostelId: widget.hostelId,
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        gstin: _gstinCtrl.text.trim(),
        gstEnabled: _gstEnabled,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: Colors.teal,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hostel Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionLabel('Basic Information'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Hostel name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home_work_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Address *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'City *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact phone',
                        border: OutlineInputBorder(),
                        prefixText: '+91 ',
                        prefixIcon: Icon(Icons.phone_outlined),
                        counterText: '',
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel('GST Settings'),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: _gstEnabled,
                      onChanged: (v) => setState(() => _gstEnabled = v),
                      title: const Text('Enable GST on invoices'),
                      subtitle: const Text(
                          'Adds 9% CGST + 9% SGST (18% total) to rent'),
                      tileColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    if (_gstEnabled) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _gstinCtrl,
                        decoration: const InputDecoration(
                          labelText: 'GSTIN',
                          border: OutlineInputBorder(),
                          hintText: 'e.g. 22AAAAA0000A1Z5',
                          prefixIcon: Icon(Icons.receipt_long_outlined),
                          counterText: '',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 15,
                      ),
                    ],
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving...' : 'Save settings'),
                      onPressed: _saving ? null : _save,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8),
    );
  }
}

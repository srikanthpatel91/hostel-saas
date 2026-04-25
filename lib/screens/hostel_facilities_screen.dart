import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

class HostelFacilitiesScreen extends StatefulWidget {
  final String hostelId;
  const HostelFacilitiesScreen({super.key, required this.hostelId});

  @override
  State<HostelFacilitiesScreen> createState() =>
      _HostelFacilitiesScreenState();
}

class _HostelFacilitiesScreenState extends State<HostelFacilitiesScreen> {
  // Map of facility key → display label.
  // Add more here when a real owner asks for them — one line each.
  final Map<String, String> _availableFacilities = {
    'power_24_7': '24/7 power supply',
    'security_24_7': '24/7 security',
    'lift': 'Lift / elevator',
    'hot_water': 'Hot water',
    'washing_machine': 'Washing machine',
  };

  Map<String, bool> _selected = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final doc = await FirebaseFirestore.instance
        .collection('hostels')
        .doc(widget.hostelId)
        .get();
    final current =
        (doc.data()?['facilities'] as Map<String, dynamic>?) ?? {};
    setState(() {
      _selected = {
        for (final key in _availableFacilities.keys)
          key: current[key] == true,
      };
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await HostelService().updateHostelFacilities(
        hostelId: widget.hostelId,
        facilities: _selected,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Facilities saved'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hostel facilities')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Tick what your hostel offers. Tenants will see these.',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._availableFacilities.entries.map((e) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: CheckboxListTile(
                          value: _selected[e.key] ?? false,
                          onChanged: (v) {
                            setState(() => _selected[e.key] = v ?? false);
                          },
                          title: Text(e.value),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save facilities'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
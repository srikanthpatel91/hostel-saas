import 'package:flutter/material.dart';
import '../services/hostel_service.dart';

class AddRoomScreen extends StatefulWidget {
  final String hostelId;
  const AddRoomScreen({super.key, required this.hostelId});

  @override
  State<AddRoomScreen> createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final _hostelService = HostelService();
  final _formKey = GlobalKey<FormState>();
  final _roomNumberController = TextEditingController();
  final _bedsController = TextEditingController(text: '1');
  final _rentController = TextEditingController();
  final _depositController = TextEditingController();

  // Simpler list — AC is now a separate checkbox, not a type
  String _selectedType = 'single';
  final List<String> _roomTypes = [
    'single',
    'double',
    'triple',
    'quad',
    'dormitory',
  ];

  bool _hasAC = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _roomNumberController.dispose();
    _bedsController.dispose();
    _rentController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _hostelService.addRoom(
        hostelId: widget.hostelId,
        roomNumber: _roomNumberController.text,
        type: _selectedType,
        totalBeds: int.parse(_bedsController.text),
        rentAmount: int.parse(_rentController.text),
        depositAmount: int.parse(_depositController.text),
        hasAC: _hasAC,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room added'),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add room')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _roomNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Room number / name',
                      hintText: 'e.g., 101, A-2, Ground Floor',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter a room number'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Room type',
                      border: OutlineInputBorder(),
                    ),
                    items: _roomTypes
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(_prettyType(t)),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedType = v ?? 'single'),
                  ),
                  const SizedBox(height: 16),

                  // AC checkbox — neat one-tap toggle
                  CheckboxListTile(
                    value: _hasAC,
                    onChanged: (v) => setState(() => _hasAC = v ?? false),
                    title: const Text('Has air conditioning'),
                    subtitle: const Text('Tap to toggle'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _bedsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total beds in this room',
                      helperText: '2 = shared by 2 people',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter a number';
                      final n = int.tryParse(v);
                      if (n == null || n < 1) return 'Must be at least 1';
                      if (n > 50) return 'Too many — split into more rooms';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _rentController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Rent per bed (₹ / month)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter rent';
                      final n = int.tryParse(v);
                      if (n == null || n < 0) return 'Invalid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _depositController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Security deposit (₹)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter deposit';
                      final n = int.tryParse(v);
                      if (n == null || n < 0) return 'Invalid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save room'),
                  ),
                ],
              ),
            ),
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
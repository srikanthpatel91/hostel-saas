import 'package:flutter/material.dart';
import '../services/hostel_service.dart';

class EditRoomScreen extends StatefulWidget {
  final String hostelId;
  final String roomId;
  final Map<String, dynamic> initialData;

  const EditRoomScreen({
    super.key,
    required this.hostelId,
    required this.roomId,
    required this.initialData,
  });

  @override
  State<EditRoomScreen> createState() => _EditRoomScreenState();
}

class _EditRoomScreenState extends State<EditRoomScreen> {
  final _hostelService = HostelService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _roomNumberController;
  late final TextEditingController _floorController;
  late final TextEditingController _bedsController;
  late final TextEditingController _rentController;
  late final TextEditingController _depositController;

  late String _selectedType;
  late bool _hasAC;
  late bool _underMaintenance;

  bool _isLoading = false;

  final List<String> _roomTypes = [
    'single',
    'double',
    'triple',
    'quad',
    'dormitory',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _roomNumberController =
        TextEditingController(text: d['roomNumber'] as String? ?? '');
    final floor = (d['floor'] as num?)?.toInt();
    _floorController =
        TextEditingController(text: floor?.toString() ?? '');
    _bedsController = TextEditingController(
        text: (d['totalBeds'] as num?)?.toInt().toString() ?? '1');
    _rentController = TextEditingController(
        text: (d['rentAmount'] as num?)?.toInt().toString() ?? '');
    _depositController = TextEditingController(
        text: (d['depositAmount'] as num?)?.toInt().toString() ?? '');
    _selectedType = d['type'] as String? ?? 'single';
    if (!_roomTypes.contains(_selectedType)) {
      _selectedType = 'single';
    }
    _hasAC = d['hasAC'] == true;
    _underMaintenance = d['underMaintenance'] == true;
  }

  @override
  void dispose() {
    _roomNumberController.dispose();
    _floorController.dispose();
    _bedsController.dispose();
    _rentController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _hostelService.updateRoom(
        hostelId: widget.hostelId,
        roomId: widget.roomId,
        roomNumber: _roomNumberController.text,
        type: _selectedType,
        totalBeds: int.parse(_bedsController.text),
        rentAmount: int.parse(_rentController.text),
        depositAmount: int.parse(_depositController.text),
        hasAC: _hasAC,
        floor: _floorController.text.trim().isEmpty
            ? null
            : int.tryParse(_floorController.text),
      );
      if (_underMaintenance != (widget.initialData['underMaintenance'] == true)) {
        await _hostelService.setRoomMaintenance(
          hostelId: widget.hostelId,
          roomId: widget.roomId,
          underMaintenance: _underMaintenance,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room updated'),
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
      appBar: AppBar(title: const Text('Edit room')),
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
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter a room number'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _floorController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Floor number (optional)',
                      hintText: 'e.g., 0 for ground, 1, 2, 3...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = int.tryParse(v);
                      if (n == null) return 'Must be a number';
                      if (n < 0 || n > 50) return 'Invalid floor';
                      return null;
                    },
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
                  CheckboxListTile(
                    value: _hasAC,
                    onChanged: (v) => setState(() => _hasAC = v ?? false),
                    title: const Text('Has air conditioning'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _bedsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total beds in this room',
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
                  const SizedBox(height: 24),
                  Card(
                    color: _underMaintenance
                        ? Colors.orange.shade50
                        : Colors.grey.shade50,
                    child: SwitchListTile(
                      value: _underMaintenance,
                      onChanged: (v) =>
                          setState(() => _underMaintenance = v),
                      title: const Text(
                        'Under maintenance',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Hide this room from vacancy count until ready again',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save changes'),
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
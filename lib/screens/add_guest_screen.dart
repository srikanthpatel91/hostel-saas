import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

class AddGuestScreen extends StatefulWidget {
  final String hostelId;
  const AddGuestScreen({super.key, required this.hostelId});

  @override
  State<AddGuestScreen> createState() => _AddGuestScreenState();
}

class _AddGuestScreenState extends State<AddGuestScreen> {
  final _hostelService = HostelService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _rentController = TextEditingController();
  final _depositController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedRoomId;
  DateTime _joinedAt = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _rentController.dispose();
    _depositController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickJoinDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joinedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _joinedAt = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick a room'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _hostelService.addGuest(
        hostelId: widget.hostelId,
        name: _nameController.text,
        phone: _phoneController.text,
        roomId: _selectedRoomId!,
        joinedAt: _joinedAt,
        rentAmount: int.parse(_rentController.text),
        depositAmount: int.parse(_depositController.text),
        notes: _notesController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guest added'),
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
      appBar: AppBar(title: const Text('Add guest')),
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
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter the name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      prefixText: '+91 ',
                      hintText: '9999999999',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter phone';
                      if (v.trim().length != 10) return 'Enter 10 digits';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Live room picker — only shows rooms with vacancy
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _hostelService.watchRooms(widget.hostelId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const LinearProgressIndicator();
                      }
                      final rooms = snapshot.data!.docs.where((d) {
                        final data = d.data();
                        if (data['underMaintenance'] == true) return false;
                        final total =
                            (data['totalBeds'] as num?)?.toInt() ?? 0;
                        final occ =
                            (data['occupiedBeds'] as num?)?.toInt() ?? 0;
                        return occ < total;
                      }).toList();

                      if (rooms.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: const Text(
                            'No rooms with vacancy. Add a room first.',
                            style: TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      return DropdownButtonFormField<String>(
                        initialValue: _selectedRoomId,
                        decoration: const InputDecoration(
                          labelText: 'Assign to room',
                          border: OutlineInputBorder(),
                        ),
                        items: rooms.map((d) {
                          final data = d.data();
                          final number = data['roomNumber'] ?? '';
                          final total =
                              (data['totalBeds'] as num?)?.toInt() ?? 0;
                          final occ =
                              (data['occupiedBeds'] as num?)?.toInt() ?? 0;
                          final vacant = total - occ;
                          final rent =
                              (data['rentAmount'] as num?)?.toInt() ?? 0;
                          return DropdownMenuItem(
                            value: d.id,
                            child: Text(
                                'Room $number  •  $vacant vacant  •  ₹$rent'),
                          );
                        }).toList(),
                        onChanged: (id) {
                          setState(() => _selectedRoomId = id);
                          // Auto-fill rent from chosen room — saves owner typing
                          if (id != null) {
                            final room = rooms.firstWhere((d) => d.id == id);
                            final roomRent =
                                (room.data()['rentAmount'] as num?)
                                        ?.toInt() ??
                                    0;
                            final roomDep =
                                (room.data()['depositAmount'] as num?)
                                        ?.toInt() ??
                                    0;
                            if (_rentController.text.isEmpty) {
                              _rentController.text = roomRent.toString();
                            }
                            if (_depositController.text.isEmpty) {
                              _depositController.text = roomDep.toString();
                            }
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date picker for join date
                  InkWell(
                    onTap: _pickJoinDate,
                    borderRadius: BorderRadius.circular(4),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Join date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(_formatDate(_joinedAt)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _rentController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly rent (₹)',
                      prefixText: '₹ ',
                      helperText: 'Auto-filled from room — change if needed',
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
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'Aadhaar number, emergency contact, etc.',
                      border: OutlineInputBorder(),
                    ),
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
                        : const Text('Add guest'),
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
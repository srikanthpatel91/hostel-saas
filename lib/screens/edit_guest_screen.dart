import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

class EditGuestScreen extends StatefulWidget {
  final String hostelId;
  final String guestId;
  final Map<String, dynamic> initialData;

  const EditGuestScreen({
    super.key,
    required this.hostelId,
    required this.guestId,
    required this.initialData,
  });

  @override
  State<EditGuestScreen> createState() => _EditGuestScreenState();
}

class _EditGuestScreenState extends State<EditGuestScreen> {
  final _hostelService = HostelService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _rentController;
  late final TextEditingController _depositController;
  late final TextEditingController _notesController;

  DateTime? _dateOfBirth;
  String _gender = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _nameController = TextEditingController(text: d['name'] as String? ?? '');

    var phone = d['phone'] as String? ?? '';
    if (phone.startsWith('+91')) phone = phone.substring(3);
    _phoneController = TextEditingController(text: phone);

    _rentController = TextEditingController(
        text: (d['rentAmount'] as num?)?.toInt().toString() ?? '');
    _depositController = TextEditingController(
        text: (d['depositAmount'] as num?)?.toInt().toString() ?? '');
    _notesController =
        TextEditingController(text: d['notes'] as String? ?? '');

    _gender = d['gender'] as String? ?? '';
    final dobTs = d['dateOfBirth'];
    if (dobTs is Timestamp) {
      _dateOfBirth = dobTs.toDate();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _rentController.dispose();
    _depositController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDOB() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _hostelService.updateGuest(
        hostelId: widget.hostelId,
        guestId: widget.guestId,
        name: _nameController.text,
        phone: _phoneController.text,
        rentAmount: int.parse(_rentController.text),
        depositAmount: int.parse(_depositController.text),
        notes: _notesController.text,
        dateOfBirth: _dateOfBirth,
        gender: _gender.isEmpty ? null : _gender,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guest updated'),
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
    final roomNumber = widget.initialData['roomNumber'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Edit guest')),
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
                  // Read-only banner: room is locked here
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Room $roomNumber  (room change not supported)',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

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
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter phone';
                      if (v.trim().length != 10) return 'Enter 10 digits';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // DOB
                  InkWell(
                    onTap: _pickDOB,
                    borderRadius: BorderRadius.circular(4),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date of birth (optional)',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.cake_outlined),
                      ),
                      child: Text(
                        _dateOfBirth == null
                            ? 'Select date of birth'
                            : _formatDate(_dateOfBirth!),
                        style: TextStyle(
                          color: _dateOfBirth == null
                              ? Colors.grey.shade500
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gender
                  const Text('Gender',
                      style: TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    emptySelectionAllowed: true,
                    segments: const [
                      ButtonSegment(value: 'male', label: Text('Male')),
                      ButtonSegment(value: 'female', label: Text('Female')),
                      ButtonSegment(value: 'other', label: Text('Other')),
                    ],
                    selected: _gender.isEmpty ? {} : {_gender},
                    onSelectionChanged: (v) =>
                        setState(() => _gender = v.isEmpty ? '' : v.first),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _rentController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly rent (₹)',
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
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Aadhaar, emergency contact, etc.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32),

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
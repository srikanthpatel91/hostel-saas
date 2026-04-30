import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// KYC Verification Screen — Aadhaar, selfie, bank details.
/// Required before user can withdraw funds.
class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();

  final _aadhaarCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();

  String? _aadhaarFrontPath, _aadhaarBackPath, _selfiePath;
  String? _aadhaarFrontUrl, _aadhaarBackUrl, _selfieUrl;
  bool _saving = false;
  String _kycStatus = 'not_started';

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final doc = await _db.collection('users').doc(uid).collection('kyc').doc('profile').get();
    if (doc.exists) {
      final d = doc.data()!;
      setState(() {
        _kycStatus = d['status'] as String? ?? 'not_started';
        _aadhaarCtrl.text = d['aadhaarNumber'] as String? ?? '';
        _panCtrl.text = d['panNumber'] as String? ?? '';
        _bankNameCtrl.text = d['bankName'] as String? ?? '';
        _accountCtrl.text = d['accountNumber'] as String? ?? '';
        _ifscCtrl.text = d['ifsc'] as String? ?? '';
        _upiCtrl.text = d['upi'] as String? ?? '';
        _aadhaarFrontUrl = d['aadhaarFrontUrl'] as String?;
        _aadhaarBackUrl = d['aadhaarBackUrl'] as String?;
        _selfieUrl = d['selfieUrl'] as String?;
      });
    }
  }

  Future<void> _pickImage(String type) async {
    final source = type == 'selfie' ? ImageSource.camera : ImageSource.gallery;
    final file = await _picker.pickImage(source: source, imageQuality: 70);
    if (file == null) return;
    setState(() {
      if (type == 'aadhaarFront') _aadhaarFrontPath = file.path;
      if (type == 'aadhaarBack') _aadhaarBackPath = file.path;
      if (type == 'selfie') _selfiePath = file.path;
    });
  }

  Future<String?> _uploadFile(String localPath, String type) async {
    final uid = _auth.currentUser?.uid ?? 'unknown';
    final ref = _storage.ref('kyc/$uid/$type.jpg');
    await ref.putFile(File(localPath));
    return ref.getDownloadURL();
  }

  Future<void> _submit() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    if (_aadhaarCtrl.text.trim().length != 12) {
      _snack('Aadhaar number must be 12 digits');
      return;
    }
    if (_accountCtrl.text.trim().isEmpty || _ifscCtrl.text.trim().isEmpty) {
      _snack('Bank account and IFSC are required');
      return;
    }

    setState(() => _saving = true);

    String? frontUrl = _aadhaarFrontUrl;
    String? backUrl = _aadhaarBackUrl;
    String? selfUrl = _selfieUrl;

    if (_aadhaarFrontPath != null) frontUrl = await _uploadFile(_aadhaarFrontPath!, 'aadhaar_front');
    if (_aadhaarBackPath != null) backUrl = await _uploadFile(_aadhaarBackPath!, 'aadhaar_back');
    if (_selfiePath != null) selfUrl = await _uploadFile(_selfiePath!, 'selfie');

    await _db.collection('users').doc(uid).collection('kyc').doc('profile').set({
      'aadhaarNumber': _aadhaarCtrl.text.trim(),
      'panNumber': _panCtrl.text.trim(),
      'bankName': _bankNameCtrl.text.trim(),
      'accountNumber': _accountCtrl.text.trim(),
      'ifsc': _ifscCtrl.text.trim(),
      'upi': _upiCtrl.text.trim(),
      'aadhaarFrontUrl': frontUrl,
      'aadhaarBackUrl': backUrl,
      'selfieUrl': selfUrl,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Update user doc
    await _db.collection('users').doc(uid).update({'kycStatus': 'pending'});

    setState(() { _saving = false; _kycStatus = 'pending'; });
    _snack('KYC submitted for review!');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KYC Verification'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusBanner(status: _kycStatus),
            const SizedBox(height: 16),

            // Aadhaar
            _Section(
              title: 'Aadhaar Details',
              icon: Icons.badge_outlined,
              children: [
                TextField(
                  controller: _aadhaarCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  enabled: _kycStatus != 'verified',
                  decoration: const InputDecoration(labelText: 'Aadhaar Number (12 digits)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _ImagePicker(
                      label: 'Front',
                      localPath: _aadhaarFrontPath,
                      url: _aadhaarFrontUrl,
                      onPick: () => _pickImage('aadhaarFront'),
                      enabled: _kycStatus != 'verified',
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _ImagePicker(
                      label: 'Back',
                      localPath: _aadhaarBackPath,
                      url: _aadhaarBackUrl,
                      onPick: () => _pickImage('aadhaarBack'),
                      enabled: _kycStatus != 'verified',
                    )),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // PAN + Selfie
            _Section(
              title: 'PAN & Selfie',
              icon: Icons.person_outlined,
              children: [
                TextField(
                  controller: _panCtrl,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 10,
                  enabled: _kycStatus != 'verified',
                  decoration: const InputDecoration(labelText: 'PAN Number (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                _ImagePicker(
                  label: 'Take Selfie',
                  localPath: _selfiePath,
                  url: _selfieUrl,
                  onPick: () => _pickImage('selfie'),
                  icon: Icons.camera_alt_outlined,
                  enabled: _kycStatus != 'verified',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bank details
            _Section(
              title: 'Bank Account',
              icon: Icons.account_balance_outlined,
              children: [
                TextField(
                  controller: _bankNameCtrl,
                  enabled: _kycStatus != 'verified',
                  decoration: const InputDecoration(labelText: 'Bank Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _accountCtrl,
                  keyboardType: TextInputType.number,
                  enabled: _kycStatus != 'verified',
                  decoration: const InputDecoration(labelText: 'Account Number', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _ifscCtrl,
                  textCapitalization: TextCapitalization.characters,
                  enabled: _kycStatus != 'verified',
                  decoration: const InputDecoration(labelText: 'IFSC Code', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _upiCtrl,
                  enabled: _kycStatus != 'verified',
                  decoration: const InputDecoration(labelText: 'UPI ID (optional)', border: OutlineInputBorder()),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_kycStatus != 'verified')
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.verified_outlined),
                  label: Text(_kycStatus == 'pending' ? 'Resubmit KYC' : 'Submit for Verification'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String message;

    switch (status) {
      case 'verified':
        color = Colors.green; icon = Icons.verified; message = 'KYC Verified — You can withdraw funds';
        break;
      case 'pending':
        color = Colors.orange; icon = Icons.pending_outlined; message = 'KYC under review (usually 1-2 business days)';
        break;
      case 'rejected':
        color = Colors.red; icon = Icons.cancel_outlined; message = 'KYC rejected — Please resubmit with correct documents';
        break;
      default:
        color = Colors.blue; icon = Icons.info_outline; message = 'Complete KYC to enable withdrawals';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Section({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ImagePicker extends StatelessWidget {
  final String label;
  final String? localPath, url;
  final VoidCallback onPick;
  final IconData icon;
  final bool enabled;
  const _ImagePicker({
    required this.label,
    this.localPath,
    this.url,
    required this.onPick,
    this.icon = Icons.upload_outlined,
    this.enabled = true,
  });

  bool get _hasImage => localPath != null || url != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPick : null,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: _hasImage ? Colors.green.withAlpha(20) : Colors.grey.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _hasImage ? Colors.green.withAlpha(80) : Colors.grey.withAlpha(60),
          ),
        ),
        child: localPath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(File(localPath!), fit: BoxFit.cover, width: double.infinity),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_hasImage ? Icons.check_circle_outline : icon,
                      color: _hasImage ? Colors.green : Colors.grey),
                  const SizedBox(height: 4),
                  Text(
                    _hasImage ? 'Uploaded ✓' : label,
                    style: TextStyle(
                      fontSize: 12,
                      color: _hasImage ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

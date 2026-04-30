import 'package:flutter/material.dart';
import '../services/hostel_service.dart';

class JoinStaffScreen extends StatefulWidget {
  const JoinStaffScreen({super.key});

  @override
  State<JoinStaffScreen> createState() => _JoinStaffScreenState();
}

class _JoinStaffScreenState extends State<JoinStaffScreen> {
  final _codeCtrl = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the invite code')));
      return;
    }
    setState(() => _joining = true);
    try {
      final result = await HostelService().acceptStaffInvite(code);
      if (!mounted) return;
      final role = result['staffRole'] as String? ?? 'staff';
      final displayRole = {
        'manager': 'Manager', 'head_master': 'Head Master',
        'warden': 'Warden', 'chef': 'Chef',
        'cleaning_head': 'Cleaning Head', 'security': 'Security',
      }[role] ?? 'Staff';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Joined ${result['hostelName']} as $displayRole!'),
          backgroundColor: Colors.teal));
      // HomeScreen's StreamBuilder picks up the role change automatically.
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join as Staff')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.vpn_key_outlined,
                size: 64, color: Colors.teal),
            const SizedBox(height: 16),
            Text(
              'Enter your invite code',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask your hostel owner for an 8-character invite code. It grants you manager access for 7 days.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              maxLength: 8,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6),
              decoration: const InputDecoration(
                hintText: 'XXXXXXXX',
                hintStyle: TextStyle(
                    fontSize: 28,
                    letterSpacing: 6,
                    color: Colors.black26),
                border: OutlineInputBorder(),
                counterText: '',
              ),
              onSubmitted: (_) => _join(),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: _joining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_joining ? 'Joining...' : 'Join hostel'),
              onPressed: _joining ? null : _join,
            ),
          ],
        ),
      ),
    );
  }
}

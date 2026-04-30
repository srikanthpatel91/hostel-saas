import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hostel_service.dart';

class StaffManagementScreen extends StatelessWidget {
  final String hostelId;
  final String hostelName;
  const StaffManagementScreen(
      {super.key, required this.hostelId, required this.hostelName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Management')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: HostelService().watchStaff(hostelId),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Generate invite
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.group_add_outlined,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer),
                          const SizedBox(width: 8),
                          Text(
                            'Invite staff member',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generate a one-time code (valid 7 days). Share it with your manager — they enter it in the app to get access.',
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withValues(alpha: 0.8)),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.vpn_key_outlined),
                        label: const Text('Generate invite code'),
                        onPressed: () =>
                            _pickRoleAndGenerate(context),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Staff list
              Text(
                docs.isEmpty ? 'No staff added yet' : 'Current staff (${docs.length})',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 8),
              if (docs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(Icons.people_outline,
                          size: 48,
                          color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('Generate a code and share it with your staff',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 13),
                          textAlign: TextAlign.center),
                    ],
                  ),
                )
              else
                ...docs.map((doc) => _StaffCard(
                    doc: doc,
                    hostelId: hostelId)),
            ],
          );
        },
      ),
    );
  }

  static const _kRoles = [
    ('manager', 'Manager', Icons.manage_accounts_outlined),
    ('warden', 'Warden', Icons.security_outlined),
    ('head_master', 'Head Master', Icons.school_outlined),
    ('chef', 'Chef', Icons.restaurant_outlined),
    ('cleaning_head', 'Cleaning Head', Icons.cleaning_services_outlined),
    ('security', 'Security', Icons.shield_outlined),
    ('staff', 'General Staff', Icons.badge_outlined),
  ];

  Future<void> _pickRoleAndGenerate(BuildContext context) async {
    String selected = 'manager';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Select staff role'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _kRoles.map((r) {
                final (val, label, icon) = r;
                final isSel = selected == val;
                return InkWell(
                  onTap: () => setS(() => selected = val),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          isSel
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: isSel ? Colors.teal : Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Icon(icon, size: 18),
                        const SizedBox(width: 8),
                        Text(label,
                            style: TextStyle(
                                fontWeight: isSel
                                    ? FontWeight.w600
                                    : FontWeight.normal)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Generate code')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final code = await HostelService().createStaffInvite(
          hostelId: hostelId, hostelName: hostelName, staffRole: selected);
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (_) => _InviteCodeDialog(code: code, role: selected),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class _InviteCodeDialog extends StatelessWidget {
  final String code;
  final String role;
  const _InviteCodeDialog({required this.code, this.role = 'manager'});

  String _roleLabel(String r) => StaffManagementScreen._kRoles
      .firstWhere((e) => e.$1 == r, orElse: () => (r, r, Icons.badge_outlined))
      .$2;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Staff Invite Code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Share this code with your ${_roleLabel(role)}. It expires in 7 days.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200, width: 2),
            ),
            child: Text(
              code,
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: Colors.teal),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied!')));
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                      text:
                          'Use this code to join as staff: $code (valid 7 days)'));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Share text copied to clipboard!')));
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done')),
      ],
    );
  }
}

class _StaffCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String hostelId;
  const _StaffCard({required this.doc, required this.hostelId});

  String _roleLabel(String r) => StaffManagementScreen._kRoles
      .firstWhere((e) => e.$1 == r, orElse: () => (r, r, Icons.badge_outlined))
      .$2;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final name = data['name'] as String? ?? 'Staff member';
    final email = data['email'] as String? ?? '';
    final joinedAt = (data['joinedAt'] as Timestamp?)?.toDate();
    final role = data['staffRole'] as String? ?? 'manager';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.teal.shade100,
          child: Text(
            name.isEmpty ? 'S' : name[0].toUpperCase(),
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.teal.shade900),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Text(_roleLabel(role),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade700)),
            ),
          ],
        ),
        subtitle: Text(
          email.isNotEmpty
              ? email
              : joinedAt != null
                  ? 'Joined ${joinedAt.day}/${joinedAt.month}/${joinedAt.year}'
                  : 'Staff',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.person_remove_outlined,
              color: Colors.red, size: 20),
          tooltip: 'Remove staff',
          onPressed: () => _confirmRemove(context, name),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove staff member?'),
        content: Text(
            '$name will lose access to this hostel immediately.'),
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
    if (ok != true) return;
    try {
      await HostelService()
          .removeStaff(hostelId: hostelId, staffUid: doc.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

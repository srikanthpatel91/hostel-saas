import 'package:flutter/material.dart';
import '../services/hostel_service.dart';
import 'daily_menu_screen.dart';

class TenantLinkScreen extends StatefulWidget {
  const TenantLinkScreen({super.key});

  @override
  State<TenantLinkScreen> createState() => _TenantLinkScreenState();
}

class _TenantLinkScreenState extends State<TenantLinkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostelIdCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _searching = false;
  bool _linking = false;
  Map<String, dynamic>? _found;

  @override
  void dispose() {
    _hostelIdCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _searching = true;
      _found = null;
    });
    try {
      final result = await HostelService().findGuestByPhone(
        hostelId: _hostelIdCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      setState(() => _found = result);
      if (result == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No active tenant found with that phone number.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _showMenuPreview(BuildContext context) {
    final hostelId = _found!['hostelId'] as String;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Today's Food Menu",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                child: DailyMenuView(
                  hostelId: hostelId,
                  date: DateTime.now(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    if (_found == null) return;
    setState(() => _linking = true);
    try {
      await HostelService().linkTenantToGuest(
        hostelId: _found!['hostelId'] as String,
        guestId: _found!['guestId'] as String,
      );
      // HomeScreen's StreamBuilder will automatically re-route once the
      // user doc updates — just pop back to trigger it.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link your tenancy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.link, size: 64, color: Colors.teal),
            const SizedBox(height: 16),
            Text(
              'Connect to your hostel',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask your hostel owner for their Hostel ID. Enter it with your registered phone number to link your account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 32),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _hostelIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Hostel ID',
                      hintText: 'Paste the ID shared by your owner',
                      prefixIcon: Icon(Icons.home_work_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Your phone number',
                      hintText: '10-digit number',
                      prefixIcon: Icon(Icons.phone_outlined),
                      prefixText: '+91 ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (v.trim().length != 10) return 'Enter 10 digits';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: _searching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search),
              label: const Text('Find my record'),
              onPressed: _searching ? null : _search,
            ),

            // Result card
            if (_found != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'We found your record:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.teal,
                        child: Text(
                          (_found!['name'] as String? ?? '?')[0].toUpperCase(),
                          style: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _found!['name'] as String? ?? '',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_found!['hostelName']}  •  Room ${_found!['roomNumber']}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Monthly rent: ₹${_found!['rentAmount']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.teal),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.restaurant_menu_outlined, size: 18),
                label: const Text('View food menu before joining'),
                onPressed: () => _showMenuPreview(context),
              ),
              const SizedBox(height: 16),
              const Text(
                'Is this you?',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: _linking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check),
                label: const Text('Yes, link my account'),
                onPressed: _linking ? null : _confirm,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _found = null),
                child: const Text('Not me — try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

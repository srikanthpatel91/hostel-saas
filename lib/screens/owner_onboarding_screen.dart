import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/hostel_service.dart';

class OwnerOnboardingScreen extends StatefulWidget {
  const OwnerOnboardingScreen({super.key});

  @override
  State<OwnerOnboardingScreen> createState() => _OwnerOnboardingScreenState();
}

class _OwnerOnboardingScreenState extends State<OwnerOnboardingScreen> {
  int _step = 0; // 0=hostel, 1=room, 2=plan, 3=done
  String? _createdHostelId;
  String? _hostelName;

  void _nextStep(String hostelId, String name) {
    setState(() {
      _createdHostelId = hostelId;
      _hostelName = name;
      _step = 1;
    });
  }

  void _goToStep(int s) => setState(() => _step = s);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _WizardStepper(currentStep: _step),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0.08, 0),
                              end: Offset.zero)
                          .animate(anim),
                      child: child,
                    )),
                child: switch (_step) {
                  0 => _Step1Hostel(
                      key: const ValueKey(0),
                      onDone: _nextStep,
                    ),
                  1 => _Step2Room(
                      key: const ValueKey(1),
                      hostelId: _createdHostelId!,
                      onNext: () => _goToStep(2),
                      onSkip: () => _goToStep(2),
                    ),
                  2 => _Step3Plan(
                      key: const ValueKey(2),
                      hostelId: _createdHostelId!,
                      onNext: () => _goToStep(3),
                    ),
                  _ => _Step4Done(
                      key: const ValueKey(3),
                      hostelName: _hostelName ?? 'your hostel',
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Progress stepper ─────────────────────────────────────────────────────────

class _WizardStepper extends StatelessWidget {
  final int currentStep;
  const _WizardStepper({required this.currentStep});

  static const _labels = ['Hostel', 'First Room', 'Plan', 'Done'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: List.generate(_labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepIdx = i ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                color: stepIdx < currentStep
                    ? cs.primary
                    : cs.outlineVariant,
              ),
            );
          }
          final stepIdx = i ~/ 2;
          final done = stepIdx < currentStep;
          final active = stepIdx == currentStep;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done || active ? cs.primary : cs.surfaceContainerHighest,
                  border: Border.all(
                      color: active ? cs.primary : Colors.transparent,
                      width: 2),
                ),
                child: Center(
                  child: done
                      ? Icon(Icons.check, size: 14, color: cs.onPrimary)
                      : Text('${stepIdx + 1}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? cs.onPrimary
                                  : cs.onSurfaceVariant)),
                ),
              ),
              const SizedBox(height: 4),
              Text(_labels[stepIdx],
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                      color: active ? cs.primary : cs.onSurfaceVariant)),
            ],
          );
        }),
      ),
    );
  }
}

// ─── Step 1: Hostel details ───────────────────────────────────────────────────

class _Step1Hostel extends StatefulWidget {
  final void Function(String hostelId, String name) onDone;
  const _Step1Hostel({super.key, required this.onDone});

  @override
  State<_Step1Hostel> createState() => _Step1HostelState();
}

class _Step1HostelState extends State<_Step1Hostel> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final id = await HostelService().createHostelAndBecomeOwner(
        hostelName: _nameCtrl.text.trim(),
        address: _addrCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      if (mounted) widget.onDone(id, _nameCtrl.text.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Icon(Icons.home_work_outlined,
                    size: 48, color: Colors.teal),
                const SizedBox(height: 12),
                Text('Tell us about your hostel',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  '15-day free trial. No payment needed yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Hostel name *',
                      hintText: 'e.g. Esa Hostel',
                      prefixIcon: Icon(Icons.home_outlined),
                      border: OutlineInputBorder()),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addrCtrl,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'Address *',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder()),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _cityCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'City *',
                      hintText: 'e.g. Hyderabad',
                      prefixIcon: Icon(Icons.location_city_outlined),
                      border: OutlineInputBorder()),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                      labelText: 'Phone number *',
                      prefixText: '+91 ',
                      hintText: '9999999999',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                      counterText: ''),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (v.trim().length != 10) return 'Enter 10 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Continue →',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Step 2: First room ───────────────────────────────────────────────────────

class _Step2Room extends StatefulWidget {
  final String hostelId;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  const _Step2Room(
      {super.key,
      required this.hostelId,
      required this.onNext,
      required this.onSkip});

  @override
  State<_Step2Room> createState() => _Step2RoomState();
}

class _Step2RoomState extends State<_Step2Room> {
  final _formKey = GlobalKey<FormState>();
  final _numCtrl = TextEditingController();
  final _bedsCtrl = TextEditingController();
  final _rentCtrl = TextEditingController();
  String _type = 'Shared';
  bool _hasAC = false;
  bool _loading = false;

  static const _roomTypes = ['Shared', 'Private', 'Dormitory', 'Suite'];

  @override
  void dispose() {
    _numCtrl.dispose();
    _bedsCtrl.dispose();
    _rentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await HostelService().addRoom(
        hostelId: widget.hostelId,
        roomNumber: _numCtrl.text.trim(),
        type: _type,
        totalBeds: int.parse(_bedsCtrl.text.trim()),
        rentAmount: int.parse(_rentCtrl.text.trim()),
        depositAmount: 0,
        hasAC: _hasAC,
        floor: 1,
      );
      if (mounted) widget.onNext();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.bed_outlined, size: 48, color: Colors.teal),
                const SizedBox(height: 12),
                Text('Add your first room',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('You can add more rooms later.',
                    style: TextStyle(
                        color:
                            cs.onSurface.withValues(alpha: 0.6)),
                    textAlign: TextAlign.center),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _numCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Room number *',
                            hintText: '101',
                            border: OutlineInputBorder()),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _bedsCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                            labelText: 'Beds *',
                            hintText: '2',
                            border: OutlineInputBorder()),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (int.tryParse(v) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                      labelText: 'Room type',
                      border: OutlineInputBorder()),
                  items: _roomTypes
                      .map((t) =>
                          DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _type = v!),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _rentCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                      labelText: 'Monthly rent ₹ *',
                      prefixIcon: Icon(Icons.currency_rupee),
                      border: OutlineInputBorder()),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (int.tryParse(v) == null) return 'Invalid';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Air conditioned'),
                  secondary: const Icon(Icons.ac_unit_outlined),
                  value: _hasAC,
                  onChanged: (v) => setState(() => _hasAC = v),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Add room & continue →',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: widget.onSkip,
                  child: Text('Skip for now',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.5))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Step 3: Choose plan ──────────────────────────────────────────────────────

class _Step3Plan extends StatefulWidget {
  final String hostelId;
  final VoidCallback onNext;
  const _Step3Plan(
      {super.key, required this.hostelId, required this.onNext});

  @override
  State<_Step3Plan> createState() => _Step3PlanState();
}

class _Step3PlanState extends State<_Step3Plan> {
  String _selected = 'pro';

  static const _plans = [
    (id: 'basic', name: 'Basic', price: '₹499/mo', icon: Icons.home_outlined),
    (id: 'pro', name: 'Pro', price: '₹999/mo', icon: Icons.rocket_launch_outlined),
    (id: 'enterprise', name: 'Enterprise', price: '₹2,499/mo', icon: Icons.corporate_fare_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.workspace_premium_outlined,
                  size: 48, color: Colors.teal),
              const SizedBox(height: 12),
              Text('Choose your plan',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                'Your 15-day trial is active. You can change plans anytime.',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ..._plans.map((p) {
                final selected = _selected == p.id;
                return GestureDetector(
                  onTap: () => setState(() => _selected = p.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? cs.primary : cs.outlineVariant,
                        width: selected ? 2 : 1,
                      ),
                      color: selected
                          ? cs.primaryContainer.withValues(alpha: 0.4)
                          : cs.surface,
                    ),
                    child: Row(
                      children: [
                        Icon(p.icon,
                            color: selected ? cs.primary : cs.onSurfaceVariant,
                            size: 24),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(p.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? cs.primary
                                      : cs.onSurface)),
                        ),
                        Text(p.price,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? cs.primary
                                    : cs.onSurfaceVariant)),
                        const SizedBox(width: 8),
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selected ? cs.primary : cs.outlineVariant,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: Colors.green.shade700, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '15-day free trial active — no payment needed today.',
                        style: TextStyle(
                            color: Colors.green.shade800,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: widget.onNext,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Start free trial →',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Step 4: Done / trial activated ──────────────────────────────────────────

class _Step4Done extends StatelessWidget {
  final String hostelName;
  const _Step4Done({super.key, required this.hostelName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle,
                    size: 64, color: Colors.green.shade600),
              ),
              const SizedBox(height: 24),
              Text('You\'re all set! 🎉',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                '$hostelName is live.\n15-day free trial activated.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    color: cs.onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 32),
              _ChecklistItem(icon: Icons.home_work, label: 'Hostel created'),
              _ChecklistItem(icon: Icons.bed, label: 'Rooms ready to manage'),
              _ChecklistItem(
                  icon: Icons.people_outline, label: 'Add your first guest'),
              _ChecklistItem(
                  icon: Icons.link,
                  label: 'Share invite link with tenants'),
              const SizedBox(height: 40),
              FilledButton.icon(
                icon: const Icon(Icons.dashboard_outlined),
                label: const Text('Go to Dashboard',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16)),
                onPressed: () => Navigator.of(context)
                    .popUntil((r) => r.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ChecklistItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: Colors.teal),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

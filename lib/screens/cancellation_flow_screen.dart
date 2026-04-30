import 'package:flutter/material.dart';
import '../services/hostel_service.dart';

class CancellationFlowScreen extends StatefulWidget {
  final String hostelId;
  const CancellationFlowScreen({super.key, required this.hostelId});

  @override
  State<CancellationFlowScreen> createState() =>
      _CancellationFlowScreenState();
}

class _CancellationFlowScreenState extends State<CancellationFlowScreen> {
  int _step = 0;
  String _reason = '';
  bool _saving = false;

  static const _reasons = [
    'Too expensive',
    'Not using it enough',
    'Switching to another system',
    'Missing features I need',
    'Technical issues',
    'Other',
  ];

  Future<void> _confirmCancel() async {
    setState(() => _saving = true);
    try {
      await HostelService().cancelSubscription(
        hostelId: widget.hostelId,
        reason: _reason,
      );
      if (mounted) setState(() => _step = 2);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cancel Subscription'),
        backgroundColor: Colors.red.shade50,
        foregroundColor: Colors.red.shade800,
      ),
      body: [_buildReasonStep(), _buildConfirmStep(), _buildDoneStep()][_step],
    );
  }

  Widget _buildReasonStep() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.sentiment_dissatisfied_outlined,
            size: 56, color: Colors.red),
        const SizedBox(height: 16),
        const Text(
          'We\'re sorry to see you go',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Please tell us why you\'re cancelling so we can improve.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        ..._reasons.map((r) {
          final selected = _reason == r;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: selected ? Colors.red.shade50 : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: selected ? Colors.red.shade300 : Colors.transparent,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _reason = r),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: selected ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(r,
                        style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal)),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed:
              _reason.isEmpty ? null : () => setState(() => _step = 1),
          child: const Text('Continue'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep my subscription'),
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 40, color: Colors.red.shade700),
                const SizedBox(height: 12),
                const Text(
                  'Are you sure?',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cancelling your subscription will:\n'
                  '• Remove access at end of current billing period\n'
                  '• Disconnect all tenant accounts\n'
                  '• Lock invoice and analytics features',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            'Reason: $_reason',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _saving ? null : _confirmCancel,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Yes, cancel my subscription'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _saving ? null : () => setState(() => _step = 0),
            child: const Text('Go back'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Keep my subscription'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDoneStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 72, color: Colors.teal),
            const SizedBox(height: 20),
            const Text(
              'Subscription cancelled',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'Your access continues until the end of the current billing period. Thank you for using Sanctuary.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => Navigator.of(context)
                  .popUntil((r) => r.isFirst),
              child: const Text('Back to dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

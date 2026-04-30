import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/hostel_service.dart';
import '../services/pdf_service.dart';

class InvoicesListScreen extends StatefulWidget {
  final String hostelId;
  const InvoicesListScreen({super.key, required this.hostelId});

  @override
  State<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends State<InvoicesListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _generating = false;

  final _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _autoGenerate();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _autoGenerate() async {
    try {
      await HostelService().generateMonthlyInvoices(
        hostelId: widget.hostelId,
        month: _now.month,
        year: _now.year,
      );
    } catch (_) {}
  }

  Future<void> _generateManual() async {
    setState(() => _generating = true);
    try {
      final count = await HostelService().generateMonthlyInvoices(
        hostelId: widget.hostelId,
        month: _now.month,
        year: _now.year,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              count == 0 ? 'All invoices already generated' : 'Created $count invoice${count == 1 ? '' : 's'}'),
          backgroundColor: count == 0 ? null : Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _markPaid(
      BuildContext context, String invoiceId, String guestName) async {
    String method = 'cash';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Mark $guestName as paid'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Payment method:'),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'cash', label: Text('Cash')),
                  ButtonSegment(value: 'upi', label: Text('UPI')),
                  ButtonSegment(value: 'bank', label: Text('Bank')),
                ],
                selected: {method},
                onSelectionChanged: (v) => setS(() => method = v.first),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm paid')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await HostelService().markInvoicePaid(
        hostelId: widget.hostelId,
        invoiceId: invoiceId,
        paymentMethod: method,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Marked as paid'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  String _periodLabel(String period) {
    final parts = period.split('-');
    if (parts.length != 2) return period;
    final month = int.tryParse(parts[1]) ?? 0;
    return '${_monthName(month)} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices & Payments'),
        actions: [
          _generating
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.add_card),
                  tooltip: 'Generate this month',
                  onPressed: _generateManual,
                ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Paid'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: HostelService().watchInvoices(widget.hostelId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data?.docs ?? [];

          return TabBarView(
            controller: _tabs,
            children: [
              _InvoiceList(
                docs: all.where((d) => d.data()['status'] != 'paid').toList(),
                hostelId: widget.hostelId,
                onMarkPaid: _markPaid,
                emptyLabel: 'No pending invoices',
                periodLabel: _periodLabel,
              ),
              _InvoiceList(
                docs: all.where((d) => d.data()['status'] == 'paid').toList(),
                hostelId: widget.hostelId,
                onMarkPaid: null,
                emptyLabel: 'No paid invoices yet',
                periodLabel: _periodLabel,
              ),
              _InvoiceList(
                docs: all,
                hostelId: widget.hostelId,
                onMarkPaid: _markPaid,
                emptyLabel: 'No invoices yet — tap + to generate',
                periodLabel: _periodLabel,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InvoiceList extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String hostelId;
  final Future<void> Function(BuildContext, String, String)? onMarkPaid;
  final String emptyLabel;
  final String Function(String) periodLabel;

  const _InvoiceList({
    required this.docs,
    required this.hostelId,
    required this.onMarkPaid,
    required this.emptyLabel,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(emptyLabel, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // Group by period
    final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped = {};
    for (final doc in docs) {
      final period = doc.data()['period'] as String? ?? '';
      grouped.putIfAbsent(period, () => []).add(doc);
    }
    final periods = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: periods.length,
      itemBuilder: (ctx, i) {
        final period = periods[i];
        final periodDocs = grouped[period]!;
        final totalAmt = periodDocs.fold<int>(
            0, (s, d) => s + ((d.data()['amount'] as num?)?.toInt() ?? 0));
        final paidCount = periodDocs.where((d) => d.data()['status'] == 'paid').length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Row(
                children: [
                  Text(
                    periodLabel(period),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    '₹$totalAmt  •  $paidCount/${periodDocs.length} paid',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            ...periodDocs.map((doc) => _InvoiceCard(
                  doc: doc,
                  hostelId: hostelId,
                  onMarkPaid: onMarkPaid,
                )),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String hostelId;
  final Future<void> Function(BuildContext, String, String)? onMarkPaid;

  const _InvoiceCard({required this.doc, required this.hostelId, required this.onMarkPaid});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final guestName = data['guestName'] as String? ?? '';
    final roomNumber = data['roomNumber'] as String? ?? '';
    final amount = (data['amount'] as num?)?.toInt() ?? 0;
    final status = data['status'] as String? ?? 'pending';
    final paidAt = (data['paidAt'] as Timestamp?)?.toDate();
    final paymentMethod = data['paymentMethod'] as String?;
    final gstEnabled = data['gstEnabled'] == true;
    final cgst = (data['cgst'] as num?)?.toInt() ?? 0;
    final sgst = (data['sgst'] as num?)?.toInt() ?? 0;
    final totalWithGst = (data['totalWithGst'] as num?)?.toInt() ?? amount;

    final (color, label) = switch (status) {
      'paid' => (Colors.green, 'Paid'),
      'overdue' => (Colors.red, 'Overdue'),
      _ => (Colors.orange, 'Pending'),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(
            guestName.isEmpty ? '?' : guestName[0].toUpperCase(),
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.9)),
          ),
        ),
        title: Text(guestName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Room $roomNumber'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('₹$totalWithGst',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color.withValues(alpha: 0.9))),
            ),
          ],
        ),
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // GST breakdown
                _AmtRow(label: 'Base rent', value: '₹$amount'),
                if (gstEnabled) ...[
                  _AmtRow(label: 'CGST (9%)', value: '₹$cgst'),
                  _AmtRow(label: 'SGST (9%)', value: '₹$sgst'),
                  const Divider(height: 8),
                  _AmtRow(
                      label: 'Total with GST',
                      value: '₹$totalWithGst',
                      bold: true),
                ],
                if (status == 'paid' && paidAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Paid via ${paymentMethod ?? '-'} on ${_fmtDate(paidAt)}',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                if (status != 'paid' && onMarkPaid != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Mark as paid'),
                    onPressed: () =>
                        onMarkPaid!(context, doc.id, guestName),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.message, size: 16,
                            color: Color(0xFF25D366)),
                        label: const Text('WhatsApp',
                            style:
                                TextStyle(color: Color(0xFF25D366))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFF25D366)),
                        ),
                        onPressed: () => _shareViaWhatsApp(
                            guestName, roomNumber, totalWithGst,
                            status, data['period'] as String? ?? ''),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.email_outlined, size: 16,
                            color: Color(0xFFEA4335)),
                        label: const Text('Gmail',
                            style:
                                TextStyle(color: Color(0xFFEA4335))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFFEA4335)),
                        ),
                        onPressed: () => _shareViaGmail(
                            guestName, roomNumber, totalWithGst,
                            status, data['period'] as String? ?? ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined,
                      size: 16, color: Colors.red),
                  label: const Text('Download PDF',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                  onPressed: () => _sharePdf(context, data),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const m = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${m[d.month]}';
  }

  Future<void> _sharePdf(
      BuildContext context, Map<String, dynamic> data) async {
    final guestName = data['guestName'] as String? ?? '';
    final roomNumber = data['roomNumber'] as String? ?? '';
    final period = data['period'] as String? ?? '';
    final baseAmount = (data['amount'] as num?)?.toInt() ?? 0;
    final cgst = (data['cgst'] as num?)?.toInt() ?? 0;
    final sgst = (data['sgst'] as num?)?.toInt() ?? 0;
    final totalWithGst =
        (data['totalWithGst'] as num?)?.toInt() ?? baseAmount;
    final gstEnabled = data['gstEnabled'] == true;
    final mealPlanAmount = (data['mealPlanAmount'] as num?)?.toInt();
    final mealPlanName = data['mealPlanName'] as String?;
    final status = data['status'] as String? ?? 'pending';
    final paidAt = (data['paidAt'] as Timestamp?)?.toDate();
    final paymentMethod = data['paymentMethod'] as String?;

    // Fetch hostel name for the PDF header
    String? hostelName;
    String? gstin;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('hostels')
          .doc(hostelId)
          .get();
      hostelName = snap.data()?['name'] as String?;
      gstin = snap.data()?['gstin'] as String?;
    } catch (_) {}

    try {
      await PdfService().shareInvoicePdf(
        guestName: guestName,
        roomNumber: roomNumber,
        period: period,
        baseAmount: baseAmount,
        cgst: cgst,
        sgst: sgst,
        totalWithGst: totalWithGst,
        gstEnabled: gstEnabled,
        mealPlanAmount: mealPlanAmount,
        mealPlanName: mealPlanName,
        status: status,
        paidAt: paidAt != null ? _fmtDate(paidAt) : null,
        paymentMethod: paymentMethod,
        hostelName: hostelName,
        gstin: gstin,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF error: $e')));
      }
    }
  }

  String _invoiceText(String guestName, String roomNumber, int amount,
      String status, String period) {
    return 'Invoice for $guestName\n'
        'Room: $roomNumber\n'
        'Period: $period\n'
        'Amount: ₹$amount\n'
        'Status: ${status[0].toUpperCase()}${status.substring(1)}';
  }

  void _shareViaWhatsApp(String guestName, String roomNumber, int amount,
      String status, String period) async {
    final text = Uri.encodeComponent(
        _invoiceText(guestName, roomNumber, amount, status, period));
    final uri = Uri.parse('https://wa.me/?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareViaGmail(String guestName, String roomNumber, int amount,
      String status, String period) async {
    final subject = Uri.encodeComponent('Invoice – $guestName ($period)');
    final body = Uri.encodeComponent(
        _invoiceText(guestName, roomNumber, amount, status, period));
    final uri = Uri.parse('mailto:?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _AmtRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _AmtRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.w700)
        : const TextStyle(color: Colors.black54, fontSize: 13);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

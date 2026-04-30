import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/hostel_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/ads_service.dart';
import 'raise_complaint_screen.dart';
import 'daily_menu_screen.dart';
import 'service_marketplace_screen.dart';
import 'wallet_screen.dart';
import 'kyc_screen.dart';
import 'withdrawal_screen.dart';
import 'qr_entry_screen.dart';
import 'document_upload_screen.dart';

// ─── Date formatter shared by multiple widgets in this file ──────────────────
String _fmtDateShort(DateTime d) {
  const m = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${m[d.month]}';
}

class TenantHomeScreen extends StatefulWidget {
  final String hostelId;
  final String guestId;
  const TenantHomeScreen(
      {super.key, required this.hostelId, required this.guestId});

  @override
  State<TenantHomeScreen> createState() => _TenantHomeScreenState();
}

class _TenantHomeScreenState extends State<TenantHomeScreen> {
  int _currentIndex = 0;
  int _newNoticesCount = 0;
  StreamSubscription? _noticesSub;

  @override
  void initState() {
    super.initState();
    // Count notices from last 7 days for the badge
    final since = DateTime.now().subtract(const Duration(days: 7));
    _noticesSub = FirebaseFirestore.instance
        .collection('hostels')
        .doc(widget.hostelId)
        .collection('notices')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(since))
        .snapshots()
        .listen((snap) {
      if (mounted) {
        // Only count notices visible to tenants
        final count = snap.docs.where((d) {
          final aud = d.data()['targetAudience'] as String? ?? 'all';
          return aud == 'all' || aud == 'tenants';
        }).length;
        setState(() => _newNoticesCount = count);
      }
    });
  }

  @override
  void dispose() {
    _noticesSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _TenantRoomTab(hostelId: widget.hostelId, guestId: widget.guestId),
      _TenantFoodMenuTab(hostelId: widget.hostelId),
      _TenantPaymentsTab(hostelId: widget.hostelId, guestId: widget.guestId),
      _TenantNoticesTab(hostelId: widget.hostelId),
      _TenantEarnTab(hostelId: widget.hostelId),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() {
            _currentIndex = i;
            // Clear badge when user opens Notices tab
            if (i == 3) _newNoticesCount = 0;
          });
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'My Room',
          ),
          const NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Food Menu',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Payments',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _newNoticesCount > 0,
              label: Text('$_newNoticesCount'),
              child: const Icon(Icons.campaign_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _newNoticesCount > 0,
              label: Text('$_newNoticesCount'),
              child: const Icon(Icons.campaign),
            ),
            label: 'Notices',
          ),
          const NavigationDestination(
            icon: Icon(Icons.monetization_on_outlined),
            selectedIcon: Icon(Icons.monetization_on),
            label: 'Earn',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab 2: Daily food menu
// ─────────────────────────────────────────────

class _TenantFoodMenuTab extends StatefulWidget {
  final String hostelId;
  const _TenantFoodMenuTab({required this.hostelId});

  @override
  State<_TenantFoodMenuTab> createState() => _TenantFoodMenuTabState();
}

class _TenantFoodMenuTabState extends State<_TenantFoodMenuTab> {
  DateTime _selectedDate = DateTime.now();
  DateTime? _lastKnownMenuUpdate;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _hostelSub;

  @override
  void initState() {
    super.initState();
    // Watch hostel doc for menuLastUpdatedAt changes → local notification
    _hostelSub = HostelService().watchHostel(widget.hostelId).listen((snap) {
      final data = snap.data();
      final updatedAt =
          (data?['menuLastUpdatedAt'] as Timestamp?)?.toDate();
      if (updatedAt == null) return;
      if (_lastKnownMenuUpdate == null) {
        // First load — store silently
        setState(() => _lastKnownMenuUpdate = updatedAt);
      } else if (updatedAt.isAfter(_lastKnownMenuUpdate!)) {
        setState(() => _lastKnownMenuUpdate = updatedAt);
        NotificationService.instance.show(
          title: 'Food Menu Updated!',
          body: 'Your hostel has updated today\'s food menu. Check it out!',
        );
      }
    });
  }

  @override
  void dispose() {
    _hostelSub?.cancel();
    super.dispose();
  }

  String _fmtDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime(d.year, d.month, d.day);
    if (sel == today) return 'Today';
    if (sel == today.add(const Duration(days: 1))) return 'Tomorrow';
    if (sel == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${d.day} ${months[d.month]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food Menu')),
      body: Column(
        children: [
          // Date navigation
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _selectedDate =
                      _selectedDate.subtract(const Duration(days: 1))),
                ),
                Expanded(
                  child: Text(
                    _fmtDate(_selectedDate),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() => _selectedDate =
                      _selectedDate.add(const Duration(days: 1))),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: DailyMenuView(
                key: ValueKey(HostelService.menuDateKey(_selectedDate)),
                hostelId: widget.hostelId,
                date: _selectedDate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab 1: Room info + rent status
// ─────────────────────────────────────────────

class _TenantRoomTab extends StatelessWidget {
  final String hostelId;
  final String guestId;
  const _TenantRoomTab({required this.hostelId, required this.guestId});

  String _fmtDate(DateTime d) {
    const m = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Room'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            HostelService().watchTenantGuest(hostelId: hostelId, guestId: guestId),
        builder: (context, gSnap) {
          if (gSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!gSnap.hasData || !gSnap.data!.exists) {
            return const Center(child: Text('Record not found'));
          }

          final g = gSnap.data!.data()!;
          final name = g['name'] as String? ?? '';
          final room = g['roomNumber'] as String? ?? '';
          final phone = g['phone'] as String? ?? '';
          final rent = (g['rentAmount'] as num?)?.toInt() ?? 0;
          final deposit = (g['depositAmount'] as num?)?.toInt() ?? 0;
          final joinedAt = (g['joinedAt'] as Timestamp?)?.toDate();
          final dob = (g['dateOfBirth'] as Timestamp?)?.toDate();
          final gender = g['gender'] as String? ?? '';
          final isActive = g['isActive'] == true;
          final mealPlanId = g['mealPlanId'] as String?;
          final mealPlanName = g['mealPlanName'] as String?;
          final mealPlanPrice = (g['mealPlanPrice'] as num?)?.toInt();

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: HostelService().watchHostel(hostelId),
            builder: (context, hSnap) {
              final hostelName =
                  hSnap.data?.data()?['name'] as String? ?? '';
              final hostelCity =
                  hSnap.data?.data()?['city'] as String? ?? '';

              // Current month invoice
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: HostelService().watchTenantInvoices(
                    hostelId: hostelId, guestId: guestId),
                builder: (context, invSnap) {
                      final now = DateTime.now();
                      final currentPeriod =
                          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
                      final currentInv = invSnap.data?.docs
                          .where((d) => d.data()['period'] == currentPeriod)
                          .firstOrNull;
                      final invStatus =
                          currentInv?.data()['status'] as String?;

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Guest header
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 32,
                                      backgroundColor: Colors.teal.shade100,
                                      child: Text(
                                        name.isEmpty
                                            ? '?'
                                            : name[0].toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.teal.shade900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(name,
                                              style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight:
                                                      FontWeight.w700)),
                                          Text(hostelName,
                                              style: TextStyle(
                                                  color:
                                                      Colors.grey.shade600)),
                                          if (hostelCity.isNotEmpty)
                                            Text(hostelCity,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors
                                                        .grey.shade500)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Room details
                            Card(
                              child: Column(
                                children: [
                                  _InfoRow(label: 'Room', value: 'Room $room'),
                                  _InfoRow(label: 'Monthly rent', value: '₹$rent'),
                                  _InfoRow(label: 'Security deposit', value: '₹$deposit'),
                                  _InfoRow(label: 'Joined', value: joinedAt != null ? _fmtDate(joinedAt) : '-'),
                                  if (phone.isNotEmpty)
                                    _InfoRow(label: 'Phone', value: phone),
                                  if (dob != null)
                                    _InfoRow(label: 'Date of birth', value: _fmtDate(dob)),
                                  if (gender.isNotEmpty)
                                    _InfoRow(
                                        label: 'Gender',
                                        value: gender[0].toUpperCase() + gender.substring(1)),
                                  _InfoRow(label: 'Status', value: isActive ? 'Active' : 'Exited', isLast: true),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Meal plan card
                            _TenantMealPlanCard(
                              hostelId: hostelId,
                              guestId: guestId,
                              planId: mealPlanId,
                              planName: mealPlanName,
                              planPrice: mealPlanPrice,
                            ),
                            const SizedBox(height: 12),

                            // Current month rent status
                            _RentStatusCard(
                                status: invStatus,
                                amount: rent,
                                month: now.month,
                                year: now.year),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.report_problem_outlined),
                              label: const Text('Raise a complaint'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RaiseComplaintScreen(
                                    hostelId: hostelId,
                                    guestId: guestId,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.storefront_outlined),
                              label: const Text('Services marketplace'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ServiceMarketplaceScreen(
                                    hostelId: hostelId,
                                    guestId: guestId,
                                    guestName: name,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.upload_file_outlined),
                              label: const Text('Upload Documents'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DocumentUploadScreen(
                                    hostelId: hostelId,
                                    guestId: guestId,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.qr_code_outlined),
                              label: const Text('My Entry QR Code'),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => QrEntryScreen(
                                    hostelId: hostelId,
                                    guestId: guestId,
                                  ),
                                ),
                              ),
                            ),
                            if (isActive)
                              _CheckoutRequestSection(
                                hostelId: hostelId,
                                guestId: guestId,
                                guestName: name,
                                roomNumber: room,
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
        },
      ),
    );
  }
}

class _RentStatusCard extends StatelessWidget {
  final String? status;
  final int amount;
  final int month;
  final int year;

  const _RentStatusCard(
      {required this.status,
      required this.amount,
      required this.month,
      required this.year});

  String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  @override
  Widget build(BuildContext context) {
    final (color, icon, label, sub) = switch (status) {
      'paid' => (
          Colors.green,
          Icons.check_circle,
          'Rent paid',
          '${_monthName(month)} $year — ₹$amount'
        ),
      'overdue' => (
          Colors.red,
          Icons.warning_amber,
          'Rent overdue',
          '${_monthName(month)} $year — ₹$amount due'
        ),
      'pending' => (
          Colors.orange,
          Icons.schedule,
          'Rent due',
          '${_monthName(month)} $year — ₹$amount'
        ),
      _ => (
          Colors.grey,
          Icons.receipt_long_outlined,
          'No invoice yet',
          'Invoice not generated for ${_monthName(month)}'
        ),
    };

    return Card(
      color: color.withValues(alpha: 0.08),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w700, color: color)),
        subtitle: Text(sub),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab 2: Payment history
// ─────────────────────────────────────────────

class _TenantPaymentsTab extends StatefulWidget {
  final String hostelId;
  final String guestId;
  const _TenantPaymentsTab({required this.hostelId, required this.guestId});

  @override
  State<_TenantPaymentsTab> createState() => _TenantPaymentsTabState();
}

class _TenantPaymentsTabState extends State<_TenantPaymentsTab> {
  final _picker = ImagePicker();
  final Set<String> _uploading = {};

  Future<void> _uploadReceipt(String invoiceId) async {
    final xfile = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
    if (xfile == null) return;
    setState(() => _uploading.add(invoiceId));
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path =
          'hostels/${widget.hostelId}/receipts/${invoiceId}_$ts.${xfile.name.split('.').last}';
      final url = await StorageService().uploadXFile(
        storagePath: path,
        xfile: xfile,
      );
      await HostelService().savePaymentReceipt(
        hostelId: widget.hostelId,
        invoiceId: invoiceId,
        downloadUrl: url,
        fileName: xfile.name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Receipt uploaded — owner will confirm payment'),
          backgroundColor: Colors.teal,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading.remove(invoiceId));
    }
  }

  String _periodLabel(String period) {
    final parts = period.split('-');
    if (parts.length != 2) return period;
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final m = int.tryParse(parts[1]) ?? 0;
    return '${months[m]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Payments')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: HostelService()
            .watchTenantInvoices(hostelId: widget.hostelId, guestId: widget.guestId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No invoices yet', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final sorted = List.of(docs)
            ..sort((a, b) => (b.data()['period'] as String? ?? '')
                .compareTo(a.data()['period'] as String? ?? ''));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sorted.length,
            itemBuilder: (ctx, i) {
              final doc = sorted[i];
              final data = doc.data();
              final invoiceId = doc.id;
              final period = data['period'] as String? ?? '';
              final amount = (data['amount'] as num?)?.toInt() ?? 0;
              final status = data['status'] as String? ?? 'pending';
              final paidAt = (data['paidAt'] as Timestamp?)?.toDate();
              final method = data['paymentMethod'] as String?;
              final receiptUrl = data['receiptUrl'] as String?;
              final receiptFileName = data['receiptFileName'] as String?;
              final isUploading = _uploading.contains(invoiceId);

              final (color, label) = switch (status) {
                'paid' => (Colors.green, 'Paid'),
                'overdue' => (Colors.red, 'Overdue'),
                _ => (Colors.orange, 'Pending'),
              };

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Icon(
                          status == 'paid' ? Icons.check : Icons.schedule,
                          color: color,
                        ),
                      ),
                      title: Text(_periodLabel(period),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(status == 'paid' && paidAt != null
                          ? 'Paid via ${method ?? '-'}'
                          : 'Due by 5th'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₹$amount',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(label,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: color)),
                          ),
                        ],
                      ),
                    ),
                    // Receipt section — only show for unpaid invoices
                    if (status != 'paid')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: receiptUrl != null
                            ? Row(
                                children: [
                                  const Icon(Icons.attach_file,
                                      size: 16, color: Colors.teal),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      receiptFileName ?? 'Receipt uploaded',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.teal),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _uploadReceipt(invoiceId),
                                    child: const Text('Replace'),
                                  ),
                                ],
                              )
                            : OutlinedButton.icon(
                                icon: isUploading
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.upload_outlined,
                                        size: 16),
                                label: const Text('Upload payment proof'),
                                onPressed: isUploading
                                    ? null
                                    : () => _uploadReceipt(invoiceId),
                              ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab 5: Earn — watch ads to earn wallet credits
// ─────────────────────────────────────────────

class _TenantEarnTab extends StatefulWidget {
  final String hostelId;
  const _TenantEarnTab({required this.hostelId});

  @override
  State<_TenantEarnTab> createState() => _TenantEarnTabState();
}

class _TenantEarnTabState extends State<_TenantEarnTab> {
  final _ads = AdsService();
  final _hs = HostelService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  int _walletBalance = 0;
  int _todayCount = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .get();
    final data = snap.data() ?? {};
    final today = DateTime.now();
    final lastDate = (data['lastAdDate'] as Timestamp?)?.toDate();
    final sameDay = lastDate != null &&
        lastDate.year == today.year &&
        lastDate.month == today.month &&
        lastDate.day == today.day;
    if (mounted) {
      setState(() {
        _walletBalance = (data['walletBalance'] as num?)?.toInt() ?? 0;
        _todayCount = sameDay ? (data['adsWatchedToday'] as num?)?.toInt() ?? 0 : 0;
      });
    }
  }

  Future<void> _watchAd() async {
    if (_todayCount >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily limit reached — come back tomorrow!')),
      );
      return;
    }
    setState(() => _loading = true);
    final ad = await _ads.fetchMatchingAd();
    setState(() => _loading = false);
    if (ad == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No ads available right now. Try again later.')),
        );
      }
      return;
    }
    if (!mounted) return;
    final earned = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdViewerDialog(ad: ad, uid: _uid, adsService: _ads),
    );
    if (earned == true) {
      await _hs.recordAdWatched(_uid);
      await _fetchStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('₹2 added to your wallet!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Earn')),
      body: RefreshIndicator(
        onRefresh: _fetchStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Balance card
            Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wallet Balance',
                        style: TextStyle(
                            fontSize: 13, color: cs.onPrimaryContainer.withValues(alpha: 0.7))),
                    const SizedBox(height: 4),
                    Text('₹$_walletBalance',
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: cs.onPrimaryContainer)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => WalletScreen(uid: _uid)),
                          ),
                          icon: Icon(Icons.account_balance_wallet_outlined,
                              size: 16, color: cs.onPrimaryContainer),
                          label: Text('Full Wallet',
                              style: TextStyle(color: cs.onPrimaryContainer)),
                        ),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => WithdrawalScreen(uid: _uid)),
                          ),
                          icon: Icon(Icons.send_outlined,
                              size: 16, color: cs.onPrimaryContainer),
                          label: Text('Withdraw',
                              style: TextStyle(color: cs.onPrimaryContainer)),
                        ),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const KycScreen()),
                          ),
                          icon: Icon(Icons.verified_outlined,
                              size: 16, color: cs.onPrimaryContainer),
                          label: Text('KYC',
                              style: TextStyle(color: cs.onPrimaryContainer)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Daily progress
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Today\'s earnings',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('₹${_todayCount * 2} / ₹20',
                            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _todayCount / 10,
                        minHeight: 8,
                        backgroundColor: cs.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('$_todayCount / 10 ads watched today',
                        style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Watch Ad button
            FilledButton.icon(
              onPressed: (_loading || _todayCount >= 10) ? null : _watchAd,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_circle_outline),
              label: Text(_todayCount >= 10
                  ? 'Daily limit reached'
                  : 'Watch Ad & Earn ₹2'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
            const SizedBox(height: 12),
            Text(
              'Watch a short 30–60 second ad to earn ₹2 in your wallet. Up to ₹20/day.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Ad viewer dialog — countdown + skip after 5s
// ─────────────────────────────────────────────

class _AdViewerDialog extends StatefulWidget {
  final Map<String, dynamic> ad;
  final String uid;
  final AdsService adsService;

  const _AdViewerDialog({
    required this.ad,
    required this.uid,
    required this.adsService,
  });

  @override
  State<_AdViewerDialog> createState() => _AdViewerDialogState();
}

class _AdViewerDialogState extends State<_AdViewerDialog> {
  Timer? _timer;
  int _remaining = 0;
  bool _completed = false;
  bool _impressionRecorded = false;

  @override
  void initState() {
    super.initState();
    _remaining = (widget.ad['duration'] as num?)?.toInt() ?? 30;
    _startTimer();
    _recordImpression();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        _onCompleted();
      }
    });
  }

  Future<void> _recordImpression() async {
    if (_impressionRecorded) return;
    _impressionRecorded = true;
    await widget.adsService.recordImpression(adId: widget.ad['id'] as String, uid: widget.uid);
  }

  Future<void> _onCompleted() async {
    await widget.adsService.recordCompletion(
        adId: widget.ad['id'] as String, uid: widget.uid);
    if (mounted) setState(() => _completed = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _totalDuration => (widget.ad['duration'] as num?)?.toInt() ?? 30;
  bool get _canSkip => _remaining <= _totalDuration - 5;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = widget.ad['title'] as String? ?? 'Ad';
    final advertiser = widget.ad['advertiserName'] as String? ?? '';
    final mediaUrl = widget.ad['mediaUrl'] as String? ?? '';
    final type = widget.ad['type'] as String? ?? 'image';

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.ads_click, size: 16),
                  const SizedBox(width: 6),
                  Text('Sponsored • $advertiser',
                      style: const TextStyle(fontSize: 12)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _completed ? 'Done!' : '${_remaining}s',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),

            // Ad media area
            Container(
              height: 240,
              color: Colors.black87,
              child: mediaUrl.isNotEmpty
                  ? (type == 'image'
                      ? Image.network(
                          mediaUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          errorBuilder: (ctx, err, st) => _AdPlaceholder(title: title),
                        )
                      : _AdPlaceholder(title: title, isVideo: true))
                  : _AdPlaceholder(title: title),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 12),
                  if (_completed)
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Claim ₹2'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44)),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: 1 - (_remaining / _totalDuration),
                            backgroundColor: cs.surfaceContainerHighest,
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: _canSkip
                              ? () => Navigator.of(context).pop(false)
                              : null,
                          child: Text(_canSkip ? 'Skip' : 'Skip in ${5 - (_totalDuration - _remaining)}s'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdPlaceholder extends StatelessWidget {
  final String title;
  final bool isVideo;
  const _AdPlaceholder({required this.title, this.isVideo = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVideo ? Icons.play_circle_outline : Icons.image_outlined,
            size: 56,
            color: Colors.white54,
          ),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab 3: Notices from hostel owner
// ─────────────────────────────────────────────

class _TenantNoticesTab extends StatelessWidget {
  final String hostelId;
  const _TenantNoticesTab({required this.hostelId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notices')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: HostelService().watchNotices(hostelId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Only show notices targeted at 'all' or 'tenants'
          final docs = (snap.data?.docs ?? []).where((d) {
            final aud = d.data()['targetAudience'] as String? ?? 'all';
            return aud == 'all' || aud == 'tenants';
          }).toList();
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No notices from your hostel',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data();
              final title = data['title'] as String? ?? '';
              final body = data['body'] as String? ?? '';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.campaign,
                              size: 18, color: Colors.teal.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                          ),
                          if (createdAt != null)
                            Text(_fmtDateShort(createdAt),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.black45)),
                        ],
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(body,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                height: 1.4)),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Checkout request section (inside Room tab)
// ─────────────────────────────────────────────

class _CheckoutRequestSection extends StatelessWidget {
  final String hostelId;
  final String guestId;
  final String guestName;
  final String roomNumber;

  const _CheckoutRequestSection({
    required this.hostelId,
    required this.guestId,
    required this.guestName,
    required this.roomNumber,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: HostelService().watchTenantCheckoutRequests(
          hostelId: hostelId, guestId: guestId),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        // Sort by createdAt descending in-app to get latest
        final sorted = List.of(docs)
          ..sort((a, b) {
            final ta =
                (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    0;
            final tb =
                (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
                    0;
            return tb.compareTo(ta);
          });
        final latestStatus =
            sorted.isNotEmpty ? sorted.first.data()['status'] as String? : null;

        if (latestStatus == 'pending') {
          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.hourglass_top,
                    color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Checkout request pending — awaiting owner approval',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }

        if (latestStatus == 'denied') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Checkout request was denied. Contact your hostel owner.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.exit_to_app_outlined),
                label: const Text('Request checkout again'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => _showCheckoutDialog(context),
              ),
            ],
          );
        }

        // No request or old approved request — show the button
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.exit_to_app_outlined),
            label: const Text('Request checkout'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => _showCheckoutDialog(context),
          ),
        );
      },
    );
  }

  void _showCheckoutDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _CheckoutRequestSheet(
        hostelId: hostelId,
        guestId: guestId,
        guestName: guestName,
        roomNumber: roomNumber,
      ),
    );
  }
}

class _CheckoutRequestSheet extends StatefulWidget {
  final String hostelId;
  final String guestId;
  final String guestName;
  final String roomNumber;

  const _CheckoutRequestSheet({
    required this.hostelId,
    required this.guestId,
    required this.guestName,
    required this.roomNumber,
  });

  @override
  State<_CheckoutRequestSheet> createState() => _CheckoutRequestSheetState();
}

class _CheckoutRequestSheetState extends State<_CheckoutRequestSheet> {
  final _noteCtrl = TextEditingController();
  DateTime? _moveOutDate;
  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _moveOutDate = picked);
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await HostelService().requestCheckout(
        hostelId: widget.hostelId,
        guestId: widget.guestId,
        guestName: widget.guestName,
        roomNumber: widget.roomNumber,
        expectedMoveOut: _moveOutDate,
        note: _noteCtrl.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.exit_to_app_outlined, color: Colors.red),
              const SizedBox(width: 8),
              const Text('Request checkout',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Your request will be sent to the hostel owner for approval.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(_moveOutDate == null
                ? 'Pick expected move-out date (optional)'
                : 'Move-out: ${_fmtDateShort(_moveOutDate!)}'),
            onPressed: _pickDate,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Reason / note (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, size: 18),
            label: Text(_saving ? 'Sending...' : 'Send request'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  const _InfoRow(
      {required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(color: Colors.grey.shade600))),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Tenant Meal Plan Card ────────────────────────────────────────────────────

class _TenantMealPlanCard extends StatelessWidget {
  final String hostelId;
  final String guestId;
  final String? planId;
  final String? planName;
  final int? planPrice;
  const _TenantMealPlanCard({
    required this.hostelId,
    required this.guestId,
    required this.planId,
    required this.planName,
    required this.planPrice,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasPlan = planName != null && planName!.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.secondaryContainer,
                  child: Icon(Icons.restaurant_outlined,
                      color: cs.onSecondaryContainer),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Meal Plan',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        hasPlan ? planName! : 'No meal plan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              hasPlan ? FontWeight.w700 : FontWeight.normal,
                          color: hasPlan
                              ? cs.onSurface
                              : cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasPlan && planPrice != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '₹$planPrice/mo',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cs.onPrimaryContainer),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: Icon(hasPlan
                  ? Icons.swap_horiz_outlined
                  : Icons.restaurant_menu_outlined),
              label: Text(hasPlan ? 'Change meal plan' : 'Subscribe to meal plan'),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => _MealPlanSubscribeSheet(
                  hostelId: hostelId,
                  guestId: guestId,
                  currentPlanId: planId,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Meal Plan Subscribe Sheet ────────────────────────────────────────────────

class _MealPlanSubscribeSheet extends StatefulWidget {
  final String hostelId;
  final String guestId;
  final String? currentPlanId;
  const _MealPlanSubscribeSheet({
    required this.hostelId,
    required this.guestId,
    this.currentPlanId,
  });

  @override
  State<_MealPlanSubscribeSheet> createState() =>
      _MealPlanSubscribeSheetState();
}

class _MealPlanSubscribeSheetState extends State<_MealPlanSubscribeSheet> {
  String? _selectedId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentPlanId;
  }

  Future<void> _save(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> plans) async {
    setState(() => _saving = true);
    try {
      if (_selectedId == null) {
        await HostelService().removeGuestMealPlan(
          hostelId: widget.hostelId,
          guestId: widget.guestId,
        );
      } else {
        final doc = plans.firstWhere((d) => d.id == _selectedId);
        final d = doc.data();
        await HostelService().assignGuestMealPlan(
          hostelId: widget.hostelId,
          guestId: widget.guestId,
          planId: doc.id,
          planName: d['name'] as String? ?? '',
          planPrice: (d['monthlyPrice'] as num?)?.toInt() ?? 0,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _mealLabel(Map<String, dynamic> d) {
    final parts = <String>[];
    if (d['breakfast'] == true) parts.add('Breakfast');
    if (d['lunch'] == true) parts.add('Lunch');
    if (d['dinner'] == true) parts.add('Dinner');
    return parts.isEmpty ? 'No meals' : parts.join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant_outlined),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Choose Meal Plan',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('hostels')
                .doc(widget.hostelId)
                .collection('meal_plans')
                .orderBy('createdAt')
                .get(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final plans = snap.data?.docs ?? [];
              if (plans.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No meal plans available.\nAsk your hostel owner to add plans.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              Widget planTile(String? value, Widget title, Widget subtitle) {
                final selected = _selectedId == value;
                final cs = Theme.of(context).colorScheme;
                return InkWell(
                  onTap: () => setState(() => _selectedId = value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: selected
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.35),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DefaultTextStyle(
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: cs.onSurface,
                                ),
                                child: title,
                              ),
                              DefaultTextStyle(
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.5)),
                                child: subtitle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  planTile(null, const Text('No meal plan'),
                      const Text('Remove current subscription')),
                  ...plans.map((doc) {
                    final d = doc.data();
                    final name = d['name'] as String? ?? '';
                    final monthly =
                        (d['monthlyPrice'] as num?)?.toInt() ?? 0;
                    return planTile(
                      doc.id,
                      Text(name),
                      Text('${_mealLabel(d)} · ₹$monthly/month'),
                    );
                  }),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving ? null : () => _save(plans),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Text('Confirm'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

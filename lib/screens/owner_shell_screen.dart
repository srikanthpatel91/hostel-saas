import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show themeNotifier;
import '../services/auth_service.dart';
import 'owner_dashboard_screen.dart';
import 'owner_onboarding_screen.dart';
import 'rooms_list_screen.dart';
import 'guests_list_screen.dart';
import 'invoices_list_screen.dart';
import 'financials_screen.dart';
import 'complaints_owner_screen.dart';
import 'checkout_requests_screen.dart';
import 'notice_board_screen.dart';
import 'daily_menu_screen.dart';
import 'inventory_screen.dart';
import 'maintenance_screen.dart';
import 'meal_plans_screen.dart';
import 'staff_management_screen.dart';
import 'hostel_facilities_screen.dart';
import 'analytics_screen.dart';
import 'multi_branch_analytics_screen.dart';
import 'hostel_settings_screen.dart';
import 'ads_admin_dashboard_screen.dart';

class OwnerShellScreen extends StatefulWidget {
  final String hostelId;
  const OwnerShellScreen({super.key, required this.hostelId});

  @override
  State<OwnerShellScreen> createState() => _OwnerShellScreenState();
}

class _OwnerShellScreenState extends State<OwnerShellScreen> {
  int _page = 0;
  bool _opsOpen = true;
  bool _tenantOpen = true;
  bool _servicesOpen = false;
  bool _financeOpen = true;
  bool _adminOpen = false;

  String _hostelName = '';

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance
        .collection('hostels')
        .doc(widget.hostelId)
        .get()
        .then((s) {
      if (mounted) setState(() => _hostelName = s.data()?['name'] ?? '');
    });
  }

  Widget _buildPage(int idx) {
    switch (idx) {
      case 1:  return RoomsListScreen(hostelId: widget.hostelId);
      case 2:  return GuestsListScreen(hostelId: widget.hostelId);
      case 3:  return InvoicesListScreen(hostelId: widget.hostelId);
      case 4:  return ComplaintsOwnerScreen(hostelId: widget.hostelId);
      case 5:  return CheckoutRequestsScreen(hostelId: widget.hostelId);
      case 6:  return NoticeBoardScreen(hostelId: widget.hostelId);
      case 7:  return DailyMenuScreen(hostelId: widget.hostelId);
      case 8:  return InventoryScreen(hostelId: widget.hostelId);
      case 9:  return MaintenanceScreen(hostelId: widget.hostelId);
      case 10: return MealPlansScreen(hostelId: widget.hostelId);
      case 11: return FinancialsScreen(hostelId: widget.hostelId);
      case 12: return AnalyticsScreen(hostelId: widget.hostelId);
      case 13: return const MultiBranchAnalyticsScreen();
      case 14: return StaffManagementScreen(hostelId: widget.hostelId, hostelName: _hostelName);
      case 15: return HostelFacilitiesScreen(hostelId: widget.hostelId);
      case 16: return HostelSettingsScreen(hostelId: widget.hostelId);
      case 17: return const AdsAdminDashboardScreen();
      default: return OwnerDashboardScreen(hostelId: widget.hostelId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            hostelId: widget.hostelId,
            hostelName: _hostelName,
            page: _page,
            opsOpen: _opsOpen,
            tenantOpen: _tenantOpen,
            servicesOpen: _servicesOpen,
            financeOpen: _financeOpen,
            adminOpen: _adminOpen,
            onSelect: (i) => setState(() => _page = i),
            onToggle: (section) => setState(() {
              switch (section) {
                case 'ops':      _opsOpen = !_opsOpen;
                case 'tenant':   _tenantOpen = !_tenantOpen;
                case 'services': _servicesOpen = !_servicesOpen;
                case 'finance':  _financeOpen = !_financeOpen;
                case 'admin':    _adminOpen = !_adminOpen;
              }
            }),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _buildPage(_page)),
        ],
      ),
    );
  }
}

// ─── Sidebar ────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final String hostelId;
  final String hostelName;
  final int page;
  final bool opsOpen;
  final bool tenantOpen;
  final bool servicesOpen;
  final bool financeOpen;
  final bool adminOpen;
  final void Function(int) onSelect;
  final void Function(String) onToggle;

  const _Sidebar({
    required this.hostelId,
    required this.hostelName,
    required this.page,
    required this.opsOpen,
    required this.tenantOpen,
    required this.servicesOpen,
    required this.financeOpen,
    required this.adminOpen,
    required this.onSelect,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg = isDark ? cs.surface : const Color(0xFF0E1117);
    final textColor = isDark ? cs.onSurface : Colors.white;
    final subTextColor = isDark ? cs.onSurfaceVariant : Colors.white54;
    final selColor = cs.primary.withValues(alpha: isDark ? 0.25 : 0.3);

    Widget item(IconData icon, String label, int idx,
        {String? badgeCollection, String? whereField, String? whereVal}) {
      final selected = page == idx;
      Widget tile = Material(
        color: selected ? selColor : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => onSelect(idx),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon,
                    size: 16,
                    color: selected ? cs.primary : subTextColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: selected ? (isDark ? cs.primary : Colors.white) : subTextColor,
                      )),
                ),
                if (badgeCollection != null)
                  _LiveBadge(
                    hostelId: hostelId,
                    collection: badgeCollection,
                    whereField: whereField,
                    whereVal: whereVal,
                  ),
              ],
            ),
          ),
        ),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        child: tile,
      );
    }

    Widget sectionHeader(String label, String key, bool open) {
      return InkWell(
        onTap: () => onToggle(key),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: subTextColor,
                    )),
              ),
              Icon(
                open ? Icons.expand_less : Icons.expand_more,
                size: 14,
                color: subTextColor,
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: 220,
      child: Material(
        color: sidebarBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Branch header ─────────────────────────────────────
            _BranchHeader(
              hostelId: hostelId,
              hostelName: hostelName,
              textColor: textColor,
              subTextColor: subTextColor,
            ),
            const SizedBox(height: 8),

            // ── Scrollable nav ───────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    item(Icons.dashboard_outlined, 'Dashboard', 0),

                    sectionHeader('OPERATIONS', 'ops', opsOpen),
                    if (opsOpen) ...[
                      item(Icons.bed_outlined, 'Rooms', 1),
                      item(Icons.people_outline, 'Guests', 2),
                      item(Icons.receipt_long_outlined, 'Invoices', 3),
                    ],

                    sectionHeader('TENANT MGMT', 'tenant', tenantOpen),
                    if (tenantOpen) ...[
                      item(Icons.report_problem_outlined, 'Complaints', 4,
                          badgeCollection: 'complaints',
                          whereField: 'status',
                          whereVal: 'open'),
                      item(Icons.exit_to_app, 'Checkout Requests', 5,
                          badgeCollection: 'checkout_requests',
                          whereField: 'status',
                          whereVal: 'pending'),
                      item(Icons.campaign_outlined, 'Notice Board', 6,
                          badgeCollection: 'notices'),
                    ],

                    sectionHeader('SERVICES', 'services', servicesOpen),
                    if (servicesOpen) ...[
                      item(Icons.restaurant_menu_outlined, 'Food Menu', 7),
                      item(Icons.inventory_2_outlined, 'Inventory', 8),
                      item(Icons.build_circle_outlined, 'Maintenance', 9,
                          badgeCollection: 'maintenance_requests',
                          whereField: 'status',
                          whereVal: 'open'),
                      item(Icons.restaurant_outlined, 'Meal Plans', 10),
                    ],

                    sectionHeader('FINANCE', 'finance', financeOpen),
                    if (financeOpen) ...[
                      item(Icons.bar_chart_outlined, 'Financials', 11),
                      item(Icons.analytics_outlined, 'Analytics & AI CFO', 12),
                      item(Icons.compare_arrows_outlined, 'Multi-Branch Compare', 13),
                    ],

                    sectionHeader('ADMIN', 'admin', adminOpen),
                    if (adminOpen) ...[
                      item(Icons.badge_outlined, 'Staff', 14),
                      item(Icons.tune, 'Facilities', 15),
                      item(Icons.settings_outlined, 'Hostel Settings', 16),
                      item(Icons.ads_click_outlined, 'Ads Dashboard', 17),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Footer ───────────────────────────────────────────
            _SidebarFooter(
              subTextColor: subTextColor,
              sidebarBg: sidebarBg,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Branch header ───────────────────────────────────────────────────────────

class _BranchHeader extends StatelessWidget {
  final String hostelId;
  final String hostelName;
  final Color textColor;
  final Color subTextColor;
  const _BranchHeader({
    required this.hostelId,
    required this.hostelName,
    required this.textColor,
    required this.subTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showBranchDropdown(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.home_work, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hostelName.isEmpty ? 'My Hostel' : hostelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor),
                  ),
                  Text(
                    'Tap to switch branch',
                    style: TextStyle(fontSize: 10, color: subTextColor),
                  ),
                ],
              ),
            ),
            Icon(Icons.expand_more, size: 18, color: subTextColor),
          ],
        ),
      ),
    );
  }

  Future<void> _showBranchDropdown(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('hostels')
        .where('ownerId', isEqualTo: uid)
        .get();
    final hostels = snap.docs;

    if (!context.mounted) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);
    final size = box.size;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + 220,
        0,
      ),
      items: [
        ...hostels.map((h) {
          final name = h.data()['name'] as String? ?? 'Hostel';
          final city = h.data()['city'] as String? ?? '';
          final isCurrent = h.id == hostelId;
          return PopupMenuItem<String>(
            value: h.id,
            child: Row(
              children: [
                Icon(
                  isCurrent
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: isCurrent ? Colors.teal : Colors.grey,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      if (city.isNotEmpty)
                        Text(city,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '__add__',
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, size: 16, color: Colors.teal),
              SizedBox(width: 10),
              Text('Add new hostel',
                  style: TextStyle(color: Colors.teal)),
            ],
          ),
        ),
      ],
    );

    if (!context.mounted || selected == null) return;
    if (selected == '__add__') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const OwnerOnboardingScreen()),
      );
      return;
    }
    if (selected == hostelId) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => OwnerShellScreen(hostelId: selected)),
    );
  }
}

// ─── Live badge (Firestore count) ────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  final String hostelId;
  final String collection;
  final String? whereField;
  final String? whereVal;
  const _LiveBadge(
      {required this.hostelId,
      required this.collection,
      this.whereField,
      this.whereVal});

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('hostels')
        .doc(hostelId)
        .collection(collection);
    if (whereField != null && whereVal != null) {
      q = q.where(whereField!, isEqualTo: whereVal);
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (_, snap) {
        final count = snap.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.teal,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        );
      },
    );
  }
}

// ─── Footer ──────────────────────────────────────────────────────────────────

class _SidebarFooter extends StatelessWidget {
  final Color subTextColor;
  final Color sidebarBg;
  const _SidebarFooter(
      {required this.subTextColor, required this.sidebarBg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white12, width: 1),
        ),
      ),
      child: Row(
        children: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (_, mode, _) => Tooltip(
              message: mode == ThemeMode.dark ? 'Light mode' : 'Dark mode',
              child: IconButton(
                icon: Icon(
                  mode == ThemeMode.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  size: 18,
                  color: subTextColor,
                ),
                splashRadius: 18,
                onPressed: () {
                  themeNotifier.value = mode == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                },
              ),
            ),
          ),
          const Spacer(),
          Tooltip(
            message: 'Sign out',
            child: IconButton(
              icon: Icon(Icons.logout, size: 18, color: subTextColor),
              splashRadius: 18,
              onPressed: () => AuthService().signOut(),
            ),
          ),
        ],
      ),
    );
  }
}

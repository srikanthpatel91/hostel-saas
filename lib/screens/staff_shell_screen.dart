import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show themeNotifier;
import '../services/auth_service.dart';
import 'owner_dashboard_screen.dart';
import 'rooms_list_screen.dart';
import 'guests_list_screen.dart';
import 'invoices_list_screen.dart';
import 'complaints_owner_screen.dart';
import 'checkout_requests_screen.dart';
import 'notice_board_screen.dart';
import 'daily_menu_screen.dart';
import 'meal_plans_screen.dart';
import 'maintenance_screen.dart';
import 'hostel_facilities_screen.dart';
import 'staff_report_screen.dart';

// ─── Data class for a nav entry ──────────────────────────────────────────────
typedef _NavEntry = ({IconData icon, String label, Widget page});

// ─── Role metadata ────────────────────────────────────────────────────────────
({String displayName, Color color}) _roleMeta(String role) => switch (role) {
      'manager'       => (displayName: 'Manager',       color: Colors.teal),
      'head_master'   => (displayName: 'Head Master',   color: Colors.indigo),
      'warden'        => (displayName: 'Warden',        color: Colors.orange),
      'chef'          => (displayName: 'Chef',           color: Colors.deepOrange),
      'cleaning_head' => (displayName: 'Cleaning Head', color: Colors.green),
      'security'      => (displayName: 'Security',      color: Colors.red),
      _               => (displayName: 'Staff',         color: Colors.grey),
    };

// ─── Main shell ───────────────────────────────────────────────────────────────

class StaffShellScreen extends StatefulWidget {
  final String hostelId;
  final String staffRole;
  const StaffShellScreen({
    super.key,
    required this.hostelId,
    required this.staffRole,
  });

  @override
  State<StaffShellScreen> createState() => _StaffShellScreenState();
}

class _StaffShellScreenState extends State<StaffShellScreen> {
  int _index = 0;

  List<_NavEntry> get _entries {
    final h = widget.hostelId;
    return switch (widget.staffRole) {
      'manager' => [
          (icon: Icons.home_outlined,           label: 'Dashboard',   page: OwnerDashboardScreen(hostelId: h)),
          (icon: Icons.bed_outlined,             label: 'Rooms',       page: RoomsListScreen(hostelId: h)),
          (icon: Icons.people_outline,           label: 'Guests',      page: GuestsListScreen(hostelId: h)),
          (icon: Icons.receipt_long_outlined,    label: 'Invoices',    page: InvoicesListScreen(hostelId: h)),
          (icon: Icons.report_problem_outlined,  label: 'Complaints',  page: ComplaintsOwnerScreen(hostelId: h)),
          (icon: Icons.logout_outlined,          label: 'Checkout',    page: CheckoutRequestsScreen(hostelId: h)),
          (icon: Icons.campaign_outlined,        label: 'Notices',     page: NoticeBoardScreen(hostelId: h)),
          (icon: Icons.build_outlined,           label: 'Maintenance', page: MaintenanceScreen(hostelId: h)),
          (icon: Icons.bar_chart_outlined,       label: 'My Report',   page: StaffReportScreen(hostelId: h, staffRole: widget.staffRole)),
        ],
      'head_master' => [
          (icon: Icons.home_outlined,            label: 'Dashboard',   page: OwnerDashboardScreen(hostelId: h)),
          (icon: Icons.bed_outlined,             label: 'Rooms',       page: RoomsListScreen(hostelId: h)),
          (icon: Icons.people_outline,           label: 'Guests',      page: GuestsListScreen(hostelId: h)),
          (icon: Icons.report_problem_outlined,  label: 'Complaints',  page: ComplaintsOwnerScreen(hostelId: h)),
          (icon: Icons.logout_outlined,          label: 'Checkout',    page: CheckoutRequestsScreen(hostelId: h)),
          (icon: Icons.campaign_outlined,        label: 'Notices',     page: NoticeBoardScreen(hostelId: h)),
          (icon: Icons.build_outlined,           label: 'Maintenance', page: MaintenanceScreen(hostelId: h)),
          (icon: Icons.bar_chart_outlined,       label: 'My Report',   page: StaffReportScreen(hostelId: h, staffRole: widget.staffRole)),
        ],
      'warden' => [
          (icon: Icons.people_outline,           label: 'Guests',      page: GuestsListScreen(hostelId: h)),
          (icon: Icons.report_problem_outlined,  label: 'Complaints',  page: ComplaintsOwnerScreen(hostelId: h)),
          (icon: Icons.logout_outlined,          label: 'Checkout',    page: CheckoutRequestsScreen(hostelId: h)),
          (icon: Icons.campaign_outlined,        label: 'Notices',     page: NoticeBoardScreen(hostelId: h)),
          (icon: Icons.bar_chart_outlined,       label: 'My Report',   page: StaffReportScreen(hostelId: h, staffRole: widget.staffRole)),
        ],
      'chef' => [
          (icon: Icons.restaurant_menu_outlined, label: 'Food Menu',   page: DailyMenuScreen(hostelId: h)),
          (icon: Icons.lunch_dining_outlined,    label: 'Meal Plans',  page: MealPlansScreen(hostelId: h)),
          (icon: Icons.campaign_outlined,        label: 'Notices',     page: NoticeBoardScreen(hostelId: h)),
          (icon: Icons.bar_chart_outlined,       label: 'My Report',   page: StaffReportScreen(hostelId: h, staffRole: widget.staffRole)),
        ],
      'cleaning_head' => [
          (icon: Icons.build_outlined,           label: 'Maintenance', page: MaintenanceScreen(hostelId: h)),
          (icon: Icons.bed_outlined,             label: 'Rooms',       page: RoomsListScreen(hostelId: h)),
          (icon: Icons.tune,                     label: 'Facilities',  page: HostelFacilitiesScreen(hostelId: h)),
          (icon: Icons.campaign_outlined,        label: 'Notices',     page: NoticeBoardScreen(hostelId: h)),
          (icon: Icons.bar_chart_outlined,       label: 'My Report',   page: StaffReportScreen(hostelId: h, staffRole: widget.staffRole)),
        ],
      'security' => [
          (icon: Icons.people_outline,           label: 'Guests',      page: GuestsListScreen(hostelId: h)),
          (icon: Icons.report_problem_outlined,  label: 'Complaints',  page: ComplaintsOwnerScreen(hostelId: h)),
          (icon: Icons.campaign_outlined,        label: 'Notices',     page: NoticeBoardScreen(hostelId: h)),
          (icon: Icons.bar_chart_outlined,       label: 'My Report',   page: StaffReportScreen(hostelId: h, staffRole: widget.staffRole)),
        ],
      _ => [
          (icon: Icons.campaign_outlined,        label: 'Notices',     page: NoticeBoardScreen(hostelId: h)),
          (icon: Icons.bar_chart_outlined,       label: 'My Report',   page: StaffReportScreen(hostelId: h, staffRole: widget.staffRole)),
        ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final safeIndex = _index.clamp(0, entries.length - 1);
    final meta = _roleMeta(widget.staffRole);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                _StaffRail(
                  entries: entries,
                  selectedIndex: safeIndex,
                  meta: meta,
                  onSelect: (i) => setState(() => _index = i),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: entries[safeIndex].page),
              ],
            ),
          );
        }

        // Narrow (phone): bottom navigation, cap at 5 tabs
        final visibleEntries = entries.take(5).toList();
        final safeBottom = safeIndex.clamp(0, visibleEntries.length - 1);

        return Scaffold(
          appBar: AppBar(
            title: _RoleBadge(displayName: meta.displayName, color: meta.color),
            actions: [
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, mode, _) => IconButton(
                  tooltip: mode == ThemeMode.dark ? 'Light mode' : 'Dark mode',
                  icon: Icon(mode == ThemeMode.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined),
                  onPressed: () {
                    themeNotifier.value = mode == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark;
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Sign out',
                onPressed: () => _confirmSignOut(context),
              ),
            ],
          ),
          body: visibleEntries[safeBottom].page,
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeBottom,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: visibleEntries
                .map((e) => NavigationDestination(
                      icon: Icon(e.icon),
                      label: e.label,
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) await AuthService().signOut();
  }
}

// ─── Navigation rail for wide screens ────────────────────────────────────────

class _StaffRail extends StatelessWidget {
  final List<_NavEntry> entries;
  final int selectedIndex;
  final ({String displayName, Color color}) meta;
  final void Function(int) onSelect;

  const _StaffRail({
    required this.entries,
    required this.selectedIndex,
    required this.meta,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        final bg = isDark ? Colors.grey.shade900 : Colors.grey.shade50;

        return Container(
          width: 140,
          color: bg,
          child: Column(
            children: [
              // Header: role badge
              const SizedBox(height: 24),
              const Icon(Icons.badge_outlined, size: 36, color: Colors.teal),
              const SizedBox(height: 8),
              _RoleBadge(displayName: meta.displayName, color: meta.color),
              const SizedBox(height: 4),
              Text(
                FirebaseAuth.instance.currentUser?.displayName ?? '',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),

              // Nav items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) {
                    final e = entries[i];
                    final selected = i == selectedIndex;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      child: Material(
                        color: selected
                            ? meta.color.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onSelect(i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 10),
                            child: Column(
                              children: [
                                Icon(
                                  e.icon,
                                  size: 22,
                                  color: selected
                                      ? meta.color
                                      : Colors.grey.shade500,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  e.label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    color: selected
                                        ? meta.color
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const Divider(height: 1),

              // Footer: dark mode + sign out
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      tooltip: mode == ThemeMode.dark
                          ? 'Light mode'
                          : 'Dark mode',
                      iconSize: 20,
                      icon: Icon(
                        mode == ThemeMode.dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        color: Colors.grey.shade500,
                      ),
                      onPressed: () {
                        themeNotifier.value = mode == ThemeMode.dark
                            ? ThemeMode.light
                            : ThemeMode.dark;
                      },
                    ),
                    Builder(
                      builder: (ctx) => IconButton(
                        tooltip: 'Sign out',
                        iconSize: 20,
                        icon: Icon(Icons.logout,
                            color: Colors.grey.shade500),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: ctx,
                            builder: (_) => AlertDialog(
                              title: const Text('Sign out?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    child: const Text('Sign out')),
                              ],
                            ),
                          );
                          if (ok == true) await AuthService().signOut();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Role badge chip ──────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String displayName;
  final Color color;
  const _RoleBadge({required this.displayName, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        displayName,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color),
      ),
    );
  }
}

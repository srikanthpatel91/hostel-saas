import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'owner_onboarding_screen.dart';
import 'owner_shell_screen.dart';
import 'staff_shell_screen.dart';
import 'hostel_picker_screen.dart';
import 'tenant_link_screen.dart';
import 'tenant_home_screen.dart';
import 'join_staff_screen.dart';

// HomeScreen is now a router: it reads the user doc and decides which
// sub-screen to show based on role.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Stream stored once in initState so theme changes don't recreate it.
  // If the stream were created inside build(), every MaterialApp theme
  // rebuild would produce a new Stream object, causing StreamBuilder to
  // restart its subscription and temporarily show a loading indicator,
  // which disposes OwnerShellScreen and resets its nav-index to 0.
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    NotificationService.instance.initialize(uid);
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('User data not found')),
          );
        }

        final data = snapshot.data!.data()!;
        final role = data['role'] as String? ?? 'guest';
        final tenantHostelId = data['tenantHostelId'] as String?;
        final tenantGuestId = data['tenantGuestId'] as String?;

        // Linked tenant → tenant home
        if (tenantHostelId != null && tenantGuestId != null) {
          return TenantHomeScreen(
            hostelId: tenantHostelId,
            guestId: tenantGuestId,
          );
        }

        // Staff → go to role-aware shell
        if (role == 'manager') {
          final managedHostelId = data['managedHostelId'] as String?;
          final staffRole = data['staffRole'] as String? ?? 'staff';
          if (managedHostelId != null) {
            return StaffShellScreen(
                hostelId: managedHostelId, staffRole: staffRole);
          }
          // Has staff role but no hostel assigned — show join screen
          return const JoinStaffScreen();
        }

        if (role == 'owner') {
          // Prefer the new hostelIds array; fall back to legacy hostelId field
          final rawIds = data['hostelIds'] as List<dynamic>?;
          final legacyId = data['hostelId'] as String?;

          final List<String> hostelIds;
          if (rawIds != null && rawIds.isNotEmpty) {
            hostelIds = rawIds.cast<String>();
          } else if (legacyId != null) {
            hostelIds = [legacyId];
          } else {
            hostelIds = [];
          }

          if (hostelIds.isEmpty) {
            // Owner but no hostel yet — let them create one
            return _GuestHomeScreen(
              name: data['name'] as String? ?? '',
              email: data['email'] as String? ?? '',
            );
          }
          if (hostelIds.length == 1) {
            // Single hostel — go straight in, no extra tap
            return OwnerShellScreen(hostelId: hostelIds.first);
          }
          // Multiple hostels — show picker
          return const HostelPickerScreen(isHomeRoute: true);
        }

        // New / unlinked user → choose path
        return _GuestHomeScreen(
          name: data['name'] as String? ?? '',
          email: data['email'] as String? ?? '',
        );
      },
    );
  }
}

class _GuestHomeScreen extends StatelessWidget {
  final String name;
  final String email;
  const _GuestHomeScreen({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hostel SaaS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.waving_hand,
                  color: Colors.amber, size: 64),
              const SizedBox(height: 16),
              Text(
                'Welcome, $name',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(email),
              const SizedBox(height: 40),
              const Text(
                'Are you a hostel owner?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set up your hostel and start managing tenants in 2 minutes.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.add_business),
                label: const Text('Set up my hostel'),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const OwnerOnboardingScreen(),
                  ));
                },
              ),
              const SizedBox(height: 12),
              const Row(children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('or', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.bed),
                label: const Text("I'm a tenant — link my room"),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const TenantLinkScreen(),
                  ));
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.badge_outlined),
                label: const Text("I have a staff invite code"),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const JoinStaffScreen(),
                  ));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'owner_onboarding_screen.dart';
import 'owner_dashboard_screen.dart';

// HomeScreen is now a router: it reads the user doc and decides which
// sub-screen to show based on role.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
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
        final hostelId = data['hostelId'] as String?;

        // Owner with hostel → dashboard
        if (role == 'owner' && hostelId != null) {
          return OwnerDashboardScreen(hostelId: hostelId);
        }

        // Guest → simple welcome with "I'm an owner" button
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
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const OwnerOnboardingScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// HostelService handles everything related to the hostels collection.
// Same pattern as AuthService — UI screens just call methods, no Firebase
// details leak into widgets.
class HostelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new hostel and promote the current user to owner.
  // Returns the new hostelId so the caller can navigate to the dashboard.
  //
  // We use a Firestore "batch" so both writes succeed together or fail
  // together — never half-done. This matters: you don't want a hostel
  // with no owner, or an owner pointing at a hostel that doesn't exist.
  Future<String> createHostelAndBecomeOwner({
    required String hostelName,
    required String address,
    required String city,
    required String phone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    // Generate the new hostel doc reference (gives us the ID upfront)
    final hostelRef = _firestore.collection('hostels').doc();
    final userRef = _firestore.collection('users').doc(user.uid);

    final now = DateTime.now();
    // 15-day trial — required for week 3 subscription logic
    final trialEnd = now.add(const Duration(days: 15));

    final batch = _firestore.batch();

    // Write 1: create the hostel
    batch.set(hostelRef, {
      'ownerId': user.uid,
      'name': hostelName.trim(),
      'address': address.trim(),
      'city': city.trim(),
      'phone': '+91${phone.trim()}',
      r'country': 'India',
      'subscription': {
        'status': 'trial',
        'plan': 'normal',
        'trialEndsAt': Timestamp.fromDate(trialEnd),
        'currentPeriodEnd': null,
        'razorpaySubscriptionId': null,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Write 2: update the user — role becomes owner, link to hostel
    batch.update(userRef, {
      'role': 'owner',
      'hostelId': hostelRef.id,
    });

    await batch.commit();
    return hostelRef.id;
  }

  // Live stream of a single hostel doc — used by owner dashboard
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchHostel(String hostelId) {
    return _firestore.collection('hostels').doc(hostelId).snapshots();
  }
}
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
      'country': 'India',
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
  // Live stream of all rooms under this hostel, ordered by room number
Stream<QuerySnapshot<Map<String, dynamic>>> watchRooms(String hostelId) {
  return _firestore
      .collection('hostels')
      .doc(hostelId)
      .collection('rooms')
      .orderBy('roomNumber')
      .snapshots();
}
// Update hostel-level facilities (lift, security, hot water, etc.)
Future<void> updateHostelFacilities({
  required String hostelId,
  required Map<String, bool> facilities,
}) async {
  await _firestore
      .collection('hostels')
      .doc(hostelId)
      .update({
    'facilities': facilities,
  });
}


// Create a new room under the hostel. Returns nothing; the live stream
// will pick up the new doc and the UI updates automatically.
// Live stream of all rooms under this hostel, ordered by room number


// Create a new room under the hostel. Returns nothing; the live stream
// will pick up the new doc and the UI updates automatically.
Future<void> addRoom({
  required String hostelId,
  required String roomNumber,
  required String type,
  required int totalBeds,
  required int rentAmount,
  required int depositAmount,
  bool hasAC = false,
  int? floor,
}) async {
  await _firestore
      .collection('hostels')
      .doc(hostelId)
      .collection('rooms')
      .add({
    'roomNumber': roomNumber.trim(),
    'type': type,
    'totalBeds': totalBeds,
    'occupiedBeds': 0,
    'rentAmount': rentAmount,
    'depositAmount': depositAmount,
    'hasAC': hasAC,
    'floor': floor,
    'status': 'vacant',
    'createdAt': FieldValue.serverTimestamp(),
  });
}

// Update a single field on a room (used by +/- bed buttons)
Future<void> updateRoomOccupancy({
  required String hostelId,
  required String roomId,
  required int occupiedBeds,
  required int totalBeds,
}) async {
  // Compute status from the numbers — single source of truth
  final String status;
  if (occupiedBeds == 0) {
    status = 'vacant';
  } else if (occupiedBeds >= totalBeds) {
    status = 'full';
  } else {
    status = 'partial';
  }

  await _firestore
      .collection('hostels')
      .doc(hostelId)
      .collection('rooms')
      .doc(roomId)
      .update({
    'occupiedBeds': occupiedBeds,
    'status': status,
  });
}

// Delete a room (with a confirmation step on the UI side)
Future<void> deleteRoom({
  required String hostelId,
  required String roomId,
}) async {
  await _firestore
      .collection('hostels')
      .doc(hostelId)
      .collection('rooms')
      .doc(roomId)
      .delete();
}
}
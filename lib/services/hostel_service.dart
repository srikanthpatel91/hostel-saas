import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// HostelService handles everything related to the hostels collection.
// UI screens just call methods, no Firebase details leak into widgets.
class HostelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new hostel and promote the current user to owner.
  // Uses a Firestore batch so both writes succeed together or fail together.
  Future<String> createHostelAndBecomeOwner({
    required String hostelName,
    required String address,
    required String city,
    required String phone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final hostelRef = _firestore.collection('hostels').doc();
    final userRef = _firestore.collection('users').doc(user.uid);

    final now = DateTime.now();
    final trialEnd = now.add(const Duration(days: 15));

    final batch = _firestore.batch();

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

  // ---------- Rooms ----------

  // Live stream of all rooms under this hostel, ordered by room number
  Stream<QuerySnapshot<Map<String, dynamic>>> watchRooms(String hostelId) {
    return _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('rooms')
        .orderBy('roomNumber')
        .snapshots();
  }

  // Create a new room under the hostel
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
      'underMaintenance': false,
      'status': 'vacant',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Update an existing room. Does NOT touch occupiedBeds — that's
  // controlled separately by updateRoomOccupancy. This way an "edit"
  // never accidentally resets occupancy.
  Future<void> updateRoom({
    required String hostelId,
    required String roomId,
    required String roomNumber,
    required String type,
    required int totalBeds,
    required int rentAmount,
    required int depositAmount,
    required bool hasAC,
    int? floor,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('rooms')
        .doc(roomId)
        .update({
      'roomNumber': roomNumber.trim(),
      'type': type,
      'totalBeds': totalBeds,
      'rentAmount': rentAmount,
      'depositAmount': depositAmount,
      'hasAC': hasAC,
      'floor': floor,
    });
  }

  // Toggle a room's maintenance status. When in maintenance, the dashboard
  // vacant-beds calculation should ignore the room.
  Future<void> setRoomMaintenance({
    required String hostelId,
    required String roomId,
    required bool underMaintenance,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('rooms')
        .doc(roomId)
        .update({
      'underMaintenance': underMaintenance,
      if (underMaintenance) 'status': 'maintenance',
    });
  }

  // Update occupied-bed count from +/- buttons
  Future<void> updateRoomOccupancy({
    required String hostelId,
    required String roomId,
    required int occupiedBeds,
    required int totalBeds,
  }) async {
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

  // Delete a room
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
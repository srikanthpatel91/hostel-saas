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

  // Live stream of all rooms under this hostel, ordered by room number.
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

  // ---------- Guests ----------

  // Live stream of all guests under this hostel (newest first)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchGuests(String hostelId) {
    return _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('guests')
        .orderBy('joinedAt', descending: true)
        .snapshots();
  }

  // Live stream of a single guest doc
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchGuest({
    required String hostelId,
    required String guestId,
  }) {
    return _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('guests')
        .doc(guestId)
        .snapshots();
  }

  // Add a guest AND atomically increment the room's occupiedBeds.
  // We use a Firestore transaction so the two writes are all-or-nothing.
  // If the room is already full, the whole operation aborts safely.
  Future<void> addGuest({
    required String hostelId,
    required String name,
    required String phone,
    required String roomId,
    required DateTime joinedAt,
    required int rentAmount,
    required int depositAmount,
    String? notes,
  }) async {
    final hostelRef = _firestore.collection('hostels').doc(hostelId);
    final roomRef = hostelRef.collection('rooms').doc(roomId);
    final guestRef = hostelRef.collection('guests').doc();

    await _firestore.runTransaction((tx) async {
      final roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) {
        throw Exception('Room not found');
      }
      final roomData = roomSnap.data()!;
      final totalBeds = (roomData['totalBeds'] as num?)?.toInt() ?? 0;
      final occupied = (roomData['occupiedBeds'] as num?)?.toInt() ?? 0;
      if (occupied >= totalBeds) {
        throw Exception('Room is full');
      }
      if (roomData['underMaintenance'] == true) {
        throw Exception('Room is under maintenance');
      }

      final newOccupied = occupied + 1;
      final newStatus = newOccupied >= totalBeds ? 'full' : 'partial';

      // Write 1: create guest doc
      tx.set(guestRef, {
        'name': name.trim(),
        'phone': '+91${phone.trim()}',
        'roomId': roomId,
        'roomNumber': roomData['roomNumber'],
        'joinedAt': Timestamp.fromDate(joinedAt),
        'exitedAt': null,
        'isActive': true,
        'rentAmount': rentAmount,
        'depositAmount': depositAmount,
        'depositStatus': 'paid',
        'notes': notes?.trim() ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Write 2: bump the room's occupied count
      tx.update(roomRef, {
        'occupiedBeds': newOccupied,
        'status': newStatus,
      });
    });
  }

  // Mark a guest as exited and atomically decrement the room's occupiedBeds.
  // Same transaction pattern: both succeed or both fail.
  Future<void> markGuestExited({
    required String hostelId,
    required String guestId,
  }) async {
    final hostelRef = _firestore.collection('hostels').doc(hostelId);
    final guestRef = hostelRef.collection('guests').doc(guestId);

    await _firestore.runTransaction((tx) async {
      final guestSnap = await tx.get(guestRef);
      if (!guestSnap.exists) throw Exception('Guest not found');
      final guestData = guestSnap.data()!;
      if (guestData['isActive'] != true) {
        // Already exited — nothing to do
        return;
      }
      final roomId = guestData['roomId'] as String?;
      if (roomId == null) throw Exception('Guest has no room linked');

      final roomRef = hostelRef.collection('rooms').doc(roomId);
      final roomSnap = await tx.get(roomRef);

      // Mark guest exited
      tx.update(guestRef, {
        'isActive': false,
        'exitedAt': FieldValue.serverTimestamp(),
      });

      // Decrement room occupancy if room still exists
      if (roomSnap.exists) {
        final roomData = roomSnap.data()!;
        final totalBeds = (roomData['totalBeds'] as num?)?.toInt() ?? 0;
        final occupied = (roomData['occupiedBeds'] as num?)?.toInt() ?? 0;
        final newOccupied = (occupied - 1).clamp(0, totalBeds);
        final newStatus = newOccupied == 0
            ? 'vacant'
            : (newOccupied >= totalBeds ? 'full' : 'partial');
        tx.update(roomRef, {
          'occupiedBeds': newOccupied,
          'status': newStatus,
        });
      }
    });
  }
}
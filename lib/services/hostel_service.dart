import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
      // hostelId kept for backward-compat reads; always points to latest hostel
      'hostelId': hostelRef.id,
      // hostelIds is the authoritative multi-hostel list
      'hostelIds': FieldValue.arrayUnion([hostelRef.id]),
    });

    await batch.commit();
    return hostelRef.id;
  }

  // Live stream of a single hostel doc — used by owner dashboard
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchHostel(String hostelId) {
    return _firestore.collection('hostels').doc(hostelId).snapshots();
  }

  // Live stream of all hostels owned by a given user — used by hostel picker
  Stream<QuerySnapshot<Map<String, dynamic>>> watchOwnerHostels(String uid) {
    return _firestore
        .collection('hostels')
        .where('ownerId', isEqualTo: uid)
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
    String depositStatus = 'paid',
    int? depositPaid,
    String? notes,
    DateTime? dateOfBirth,
    String? gender,
  }) async {
    final hostelRef = _firestore.collection('hostels').doc(hostelId);
    final roomRef = hostelRef.collection('rooms').doc(roomId);
    final guestRef = hostelRef.collection('guests').doc();

    await _firestore.runTransaction((tx) async {
      final roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) throw Exception('Room not found');
      final roomData = roomSnap.data()!;
      final totalBeds = (roomData['totalBeds'] as num?)?.toInt() ?? 0;
      final occupied = (roomData['occupiedBeds'] as num?)?.toInt() ?? 0;
      if (occupied >= totalBeds) throw Exception('Room is full');
      if (roomData['underMaintenance'] == true) {
        throw Exception('Room is under maintenance');
      }

      final newOccupied = occupied + 1;
      final newStatus = newOccupied >= totalBeds ? 'full' : 'partial';

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
        'depositStatus': depositStatus,
        'depositPaid': depositPaid ?? (depositStatus == 'paid' ? depositAmount : 0),
        'notes': notes?.trim() ?? '',
        if (dateOfBirth != null) 'dateOfBirth': Timestamp.fromDate(dateOfBirth),
        if (gender != null && gender.isNotEmpty) 'gender': gender,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Write 2: bump the room's occupied count
      tx.update(roomRef, {
        'occupiedBeds': newOccupied,
        'status': newStatus,
      });
    });
  }

  // Update editable fields on a guest. We do NOT change roomId here —
// moving a guest to a different room is a more complex operation
// (would need to bump bed counts on both rooms) so it's a separate
// flow we'll add only if owners actually ask for it.
Future<void> updateGuest({
  required String hostelId,
  required String guestId,
  required String name,
  required String phone,
  required int rentAmount,
  required int depositAmount,
  required String notes,
  DateTime? dateOfBirth,
  String? gender,
}) async {
  await _firestore
      .collection('hostels')
      .doc(hostelId)
      .collection('guests')
      .doc(guestId)
      .update({
    'name': name.trim(),
    'phone': '+91${phone.trim()}',
    'rentAmount': rentAmount,
    'depositAmount': depositAmount,
    'notes': notes.trim(),
    if (dateOfBirth != null) 'dateOfBirth': Timestamp.fromDate(dateOfBirth),
    'gender': gender ?? '',
  });
}
  // ---------- Invoices ----------

  Stream<QuerySnapshot<Map<String, dynamic>>> watchInvoices(String hostelId) {
    return _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('invoices')
        .orderBy('dueDate', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTenantInvoices({
    required String hostelId,
    required String guestId,
  }) {
    return _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('invoices')
        .where('guestId', isEqualTo: guestId)
        .snapshots();
  }

  // Idempotent — safe to call multiple times for the same month.
  Future<int> generateMonthlyInvoices({
    required String hostelId,
    required int month,
    required int year,
  }) async {
    final hostelRef = _firestore.collection('hostels').doc(hostelId);
    final period =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

    // Check hostel GST settings
    final hostelSnap = await hostelRef.get();
    final hostelData = hostelSnap.data() ?? {};
    final gstEnabled = hostelData['gstEnabled'] == true;
    final gstin = hostelData['gstin'] as String? ?? '';

    final guestsSnap = await hostelRef
        .collection('guests')
        .where('isActive', isEqualTo: true)
        .get();
    if (guestsSnap.docs.isEmpty) return 0;

    final existingSnap = await hostelRef
        .collection('invoices')
        .where('period', isEqualTo: period)
        .get();
    final existingGuestIds =
        existingSnap.docs.map((d) => d.data()['guestId'] as String).toSet();

    final dueDate = DateTime(year, month, 5);
    final now = DateTime.now();
    final defaultStatus = now.isAfter(dueDate) ? 'overdue' : 'pending';

    final batch = _firestore.batch();
    int created = 0;

    for (final guestDoc in guestsSnap.docs) {
      if (existingGuestIds.contains(guestDoc.id)) continue;
      final d = guestDoc.data();
      final baseAmount = (d['rentAmount'] as num?)?.toInt() ?? 0;
      final mealPlanPrice = (d['mealPlanPrice'] as num?)?.toInt() ?? 0;
      final mealPlanName = d['mealPlanName'] as String?;

      // GST: 9% CGST + 9% SGST = 18% for intra-state services (on rent only)
      final cgst = gstEnabled ? (baseAmount * 0.09).round() : 0;
      final sgst = gstEnabled ? (baseAmount * 0.09).round() : 0;
      final totalWithGst = baseAmount + cgst + sgst + mealPlanPrice;

      final ref = hostelRef.collection('invoices').doc();
      batch.set(ref, {
        'guestId': guestDoc.id,
        'guestName': d['name'] ?? '',
        'roomNumber': d['roomNumber'] ?? '',
        'roomId': d['roomId'] ?? '',
        'amount': baseAmount,
        'gstEnabled': gstEnabled,
        'cgst': cgst,
        'sgst': sgst,
        'totalWithGst': totalWithGst,
        'gstin': gstin,
        if (mealPlanPrice > 0) 'mealPlanAmount': mealPlanPrice,
        if (mealPlanPrice > 0 && mealPlanName != null) 'mealPlanName': mealPlanName,
        'period': period,
        'dueDate': Timestamp.fromDate(dueDate),
        'status': defaultStatus,
        'paidAt': null,
        'paymentMethod': null,
        'notes': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      created++;
    }

    if (created > 0) await batch.commit();
    return created;
  }

  Future<void> markInvoicePaid({
    required String hostelId,
    required String invoiceId,
    required String paymentMethod,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('invoices')
        .doc(invoiceId)
        .update({
      'status': 'paid',
      'paidAt': FieldValue.serverTimestamp(),
      'paymentMethod': paymentMethod,
    });
  }

  // Tenant uploads payment proof — stores URL on the invoice.
  // Owner sees the receipt indicator and can then mark as paid.
  Future<void> savePaymentReceipt({
    required String hostelId,
    required String invoiceId,
    required String downloadUrl,
    required String fileName,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('invoices')
        .doc(invoiceId)
        .update({
      'receiptUrl': downloadUrl,
      'receiptFileName': fileName,
      'receiptUploadedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Tenant linking ----------

  Future<Map<String, dynamic>?> findGuestByPhone({
    required String hostelId,
    required String phone,
  }) async {
    final normalized = '+91${phone.trim()}';
    final snap = await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('guests')
        .where('phone', isEqualTo: normalized)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;

    final hostelSnap =
        await _firestore.collection('hostels').doc(hostelId).get();
    final hostelName = hostelSnap.data()?['name'] as String? ?? '';

    final doc = snap.docs.first;
    return {'guestId': doc.id, 'hostelId': hostelId, 'hostelName': hostelName, ...doc.data()};
  }

  Future<void> linkTenantToGuest({
    required String hostelId,
    required String guestId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');

    final batch = _firestore.batch();
    batch.update(_firestore.collection('users').doc(uid), {
      'tenantHostelId': hostelId,
      'tenantGuestId': guestId,
    });
    batch.update(
      _firestore
          .collection('hostels')
          .doc(hostelId)
          .collection('guests')
          .doc(guestId),
      {'linkedUserId': uid},
    );
    await batch.commit();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchTenantGuest({
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

  // ---------- Wallet ----------

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserDoc(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  Future<void> addBonusToWallet({
    required String uid,
    required int amount,
    required String reason,
  }) async {
    final ref = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final wallet =
          (snap.data()?['wallet'] as Map<String, dynamic>?) ?? {};
      final current = (wallet['bonus'] as num?)?.toInt() ?? 0;
      tx.update(ref, {'wallet.bonus': current + amount});
    });
    // Log to wallet_ledger subcollection for audit
    await ref.collection('wallet_ledger').add({
      'type': 'credit',
      'bucket': 'bonus',
      'amount': amount,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
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

  // ---------- Expenses ----------

  static const expenseCategories = [
    'Salary', 'Electricity', 'Water', 'Internet',
    'Maintenance', 'Groceries', 'Other',
  ];

  Future<void> addExpense({
    required String hostelId,
    required String category,
    required int amount,
    required String description,
    required DateTime date,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('expenses')
        .add({
      'category': category,
      'amount': amount,
      'description': description.trim(),
      'date': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchExpenses(String hostelId) {
    return _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> deleteExpense({
    required String hostelId,
    required String expenseId,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('expenses')
        .doc(expenseId)
        .delete();
  }

  // ---------- Deposit tracking ----------

  Future<void> updateDepositStatus({
    required String hostelId,
    required String guestId,
    required String depositStatus,
    required int depositPaid,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('guests')
        .doc(guestId)
        .update({'depositStatus': depositStatus, 'depositPaid': depositPaid});
  }

  // ---------- Subscription management ----------

  Future<void> cancelSubscription({
    required String hostelId,
    required String reason,
  }) async {
    await _firestore.collection('hostels').doc(hostelId).update({
      'subscription.status': 'cancelled',
      'subscription.cancelledAt': FieldValue.serverTimestamp(),
      'subscription.cancelReason': reason,
    });
  }

  Future<void> pauseSubscription({
    required String hostelId,
    required int months,
  }) async {
    final resumeAt = DateTime.now().add(Duration(days: months * 30));
    await _firestore.collection('hostels').doc(hostelId).update({
      'subscription.status': 'paused',
      'subscription.pausedAt': FieldValue.serverTimestamp(),
      'subscription.resumeAt': Timestamp.fromDate(resumeAt),
    });
  }

  Future<void> retryPayment(String hostelId) async {
    // In production this would trigger a Razorpay retry via Cloud Function.
    // For now we reset the failed status so the owner can continue using the app.
    await _firestore.collection('hostels').doc(hostelId).update({
      'subscription.status': 'trial',
      'subscription.paymentRetryAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addSubscriptionInvoice({
    required String hostelId,
    required String plan,
    required int amount,
    required String status, // 'paid' | 'failed'
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('subscription_invoices')
        .add({
      'plan': plan,
      'amount': amount,
      'status': status,
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSubscriptionInvoices(
      String hostelId) {
    return _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('subscription_invoices')
        .orderBy('createdAt', descending: true)
        .limit(12)
        .snapshots();
  }

  // ---------- Complaints ----------

  static const complaintCategories = [
    'Maintenance', 'Cleanliness', 'Noise', 'Water',
    'Electricity', 'Internet', 'Security', 'Other',
  ];

  Future<void> raiseComplaint({
    required String hostelId,
    required String guestId,
    required String guestName,
    required String roomNumber,
    required String category,
    required String description,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('complaints')
        .add({
      'guestId': guestId,
      'guestName': guestName,
      'roomNumber': roomNumber,
      'category': category,
      'description': description.trim(),
      'status': 'open',
      'ownerNotes': '',
      'resolvedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchComplaints(String hostelId) {
    return _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('complaints')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTenantComplaints({
    required String hostelId,
    required String guestId,
  }) {
    return _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('complaints')
        .where('guestId', isEqualTo: guestId)
        .snapshots();
  }

  Future<void> updateComplaintStatus({
    required String hostelId,
    required String complaintId,
    required String status,
    String ownerNotes = '',
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('complaints')
        .doc(complaintId)
        .update({
      'status': status,
      'ownerNotes': ownerNotes.trim(),
      if (status == 'resolved') 'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Ad rewards ----------

  Future<bool> canWatchAd(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    final data = snap.data() ?? {};
    final today = _todayString();
    final lastAdDate = data['lastAdDate'] as String? ?? '';
    final adsToday = lastAdDate == today
        ? (data['adsWatchedToday'] as num?)?.toInt() ?? 0
        : 0;
    return adsToday < 10;
  }

  Future<void> recordAdWatched(String uid) async {
    final ref = _firestore.collection('users').doc(uid);
    final today = _todayString();
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final lastAdDate = data['lastAdDate'] as String? ?? '';
      final adsToday = lastAdDate == today
          ? (data['adsWatchedToday'] as num?)?.toInt() ?? 0
          : 0;
      if (adsToday >= 10) throw Exception('Daily ad limit reached');

      final wallet = (data['wallet'] as Map<String, dynamic>?) ?? {};
      final currentBonus = (wallet['bonus'] as num?)?.toInt() ?? 0;

      tx.update(ref, {
        'adsWatchedToday': adsToday + 1,
        'lastAdDate': today,
        'wallet.bonus': currentBonus + 2,
      });
    });
    await ref.collection('wallet_ledger').add({
      'type': 'credit',
      'bucket': 'bonus',
      'amount': 2,
      'reason': 'Ad reward',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

  // ---------- FCM token ----------

  Future<void> saveFcmToken({
    required String uid,
    required String token,
  }) async {
    await _firestore.collection('users').doc(uid).update({'fcmToken': token});
  }

  // ---------- Maintenance requests ----------

  static const maintenanceCategories = [
    'Plumbing', 'Electrical', 'Furniture', 'AC/Cooling', 'Structural', 'Other',
  ];

  Future<void> addMaintenanceRequest({
    required String hostelId,
    required String title,
    required String description,
    required String category,
    required String priority,
    String? roomId,
    String? roomNumber,
    int? estimatedCost,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('maintenance_requests')
        .add({
      'title': title.trim(),
      'description': description.trim(),
      'category': category,
      'priority': priority,
      'roomId': roomId,
      'roomNumber': roomNumber,
      'status': 'open',
      'estimatedCost': estimatedCost,
      'actualCost': null,
      'notes': '',
      'reportedAt': FieldValue.serverTimestamp(),
      'completedAt': null,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMaintenanceRequests(
      String hostelId) {
    return _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('maintenance_requests')
        .orderBy('reportedAt', descending: true)
        .snapshots();
  }

  Future<void> updateMaintenanceRequest({
    required String hostelId,
    required String requestId,
    required String status,
    String? notes,
    int? actualCost,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('maintenance_requests')
        .doc(requestId)
        .update({
      'status': status,
      'notes': ?notes?.trim(),
      'actualCost': ?actualCost,
      if (status == 'completed') 'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMaintenanceRequest({
    required String hostelId,
    required String requestId,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('maintenance_requests')
        .doc(requestId)
        .delete();
  }

  // ---------- Meal plans ----------

  Future<void> addMealPlan({
    required String hostelId,
    required String name,
    required bool breakfast,
    required bool lunch,
    required bool dinner,
    required int weeklyPrice,
    required int monthlyPrice,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('meal_plans')
        .add({
      'name': name.trim(),
      'breakfast': breakfast,
      'lunch': lunch,
      'dinner': dinner,
      'weeklyPrice': weeklyPrice,
      'monthlyPrice': monthlyPrice,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMealPlans(String hostelId) {
    return _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('meal_plans')
        .orderBy('createdAt')
        .snapshots();
  }

  Future<void> deleteMealPlan({
    required String hostelId,
    required String planId,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('meal_plans')
        .doc(planId)
        .delete();
  }

  Future<void> assignGuestMealPlan({
    required String hostelId,
    required String guestId,
    required String planId,
    required String planName,
    required int planPrice,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('guests')
        .doc(guestId)
        .update({
      'mealPlanId': planId,
      'mealPlanName': planName,
      'mealPlanPrice': planPrice,
    });
  }

  Future<void> removeGuestMealPlan({
    required String hostelId,
    required String guestId,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('guests')
        .doc(guestId)
        .update({
      'mealPlanId': null,
      'mealPlanName': null,
      'mealPlanPrice': null,
    });
  }

  // ---------- Staff / invites ----------

  // Creates a root-level invite doc keyed by the code itself for easy lookup.
  Future<String> createStaffInvite({
    required String hostelId,
    required String hostelName,
    String staffRole = 'manager',
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    final code = _generateInviteCode();
    await _firestore.collection('staff_invites').doc(code).set({
      'hostelId': hostelId,
      'hostelName': hostelName,
      'staffRole': staffRole,
      'createdByUid': uid,
      'status': 'pending',
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
      'acceptedByUid': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchStaff(String hostelId) {
    return _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('staff')
        .snapshots();
  }

  Future<void> removeStaff({
    required String hostelId,
    required String staffUid,
  }) async {
    final batch = _firestore.batch();
    batch.delete(_firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('staff')
        .doc(staffUid));
    batch.update(_firestore.collection('users').doc(staffUid), {
      'role': 'guest',
      'managedHostelId': null,
    });
    await batch.commit();
  }

  // Accepts a staff invite: links the current user as manager to the hostel.
  Future<Map<String, dynamic>> acceptStaffInvite(String rawCode) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in');
    final code = rawCode.trim().toUpperCase();
    final inviteRef = _firestore.collection('staff_invites').doc(code);

    return await _firestore.runTransaction((tx) async {
      final inviteSnap = await tx.get(inviteRef);
      if (!inviteSnap.exists) throw Exception('Invite code not found');
      final d = inviteSnap.data()!;
      if (d['status'] != 'pending') throw Exception('Code already used');
      final expiresAt = (d['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) throw Exception('Code expired');

      final hostelId = d['hostelId'] as String;
      final hostelName = d['hostelName'] as String;

      final userRef = _firestore.collection('users').doc(uid);
      final userSnap = await tx.get(userRef);
      final userName = userSnap.data()?['name'] as String? ?? '';
      final userEmail = userSnap.data()?['email'] as String? ?? '';

      final staffRole = d['staffRole'] as String? ?? 'manager';
      tx.update(inviteRef, {'status': 'accepted', 'acceptedByUid': uid});
      tx.update(userRef, {'role': 'manager', 'managedHostelId': hostelId, 'staffRole': staffRole});
      tx.set(
        _firestore.collection('hostels').doc(hostelId).collection('staff').doc(uid),
        {
          'userId': uid,
          'name': userName,
          'email': userEmail,
          'staffRole': staffRole,
          'joinedAt': FieldValue.serverTimestamp(),
        },
      );
      return {'hostelId': hostelId, 'hostelName': hostelName, 'staffRole': staffRole};
    });
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ---------- Guest documents ----------

  Future<void> saveDocumentRecord({
    required String hostelId,
    required String guestId,
    required String type,
    required String downloadUrl,
    required String fileName,
  }) async {
    final uid = _auth.currentUser?.uid;
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('guests')
        .doc(guestId)
        .collection('documents')
        .add({
      'type': type,
      'downloadUrl': downloadUrl,
      'fileName': fileName,
      'uploadedBy': uid,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchGuestDocuments({
    required String hostelId,
    required String guestId,
  }) {
    return _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('guests')
        .doc(guestId)
        .collection('documents')
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  Future<void> deleteDocumentRecord({
    required String hostelId,
    required String guestId,
    required String docId,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('guests')
        .doc(guestId)
        .collection('documents')
        .doc(docId)
        .delete();
  }

  // Deletes both the Storage file and the Firestore record atomically.
  Future<void> deleteGuestDocument({
    required String hostelId,
    required String guestId,
    required String docId,
    required String downloadUrl,
  }) async {
    try {
      await FirebaseStorage.instance.refFromURL(downloadUrl).delete();
    } catch (_) {
      // File may already be gone — continue to remove the Firestore record
    }
    await deleteDocumentRecord(
        hostelId: hostelId, guestId: guestId, docId: docId);
  }

  // ---------- Daily food menu ----------

  // Format a DateTime to the "2026-04-26" key used as the Firestore doc ID.
  static String menuDateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  // Save (or overwrite) the menu for a single date.
  // Also touches menuLastUpdatedAt on the hostel doc so tenant devices
  // can detect the change via their existing watchHostel stream.
  Future<void> saveDailyMenu({
    required String hostelId,
    required String dateKey,
    required String breakfastTime,
    required String breakfastItems,
    required String lunchTime,
    required String lunchItems,
    required String dinnerTime,
    required String dinnerItems,
    String note = '',
    String breakfastNote = '',
    String lunchNote = '',
    String dinnerNote = '',
  }) async {
    final hostelRef = _firestore.collection('hostels').doc(hostelId);
    final menuRef = hostelRef.collection('daily_menu').doc(dateKey);
    final batch = _firestore.batch();
    batch.set(menuRef, {
      'breakfast': {
        'time': breakfastTime,
        'items': breakfastItems.trim(),
        if (breakfastNote.trim().isNotEmpty) 'statusNote': breakfastNote.trim(),
      },
      'lunch': {
        'time': lunchTime,
        'items': lunchItems.trim(),
        if (lunchNote.trim().isNotEmpty) 'statusNote': lunchNote.trim(),
      },
      'dinner': {
        'time': dinnerTime,
        'items': dinnerItems.trim(),
        if (dinnerNote.trim().isNotEmpty) 'statusNote': dinnerNote.trim(),
      },
      'note': note.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(hostelRef, {'menuLastUpdatedAt': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  // Live stream for a single date's menu doc.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDailyMenu({
    required String hostelId,
    required String dateKey,
  }) {
    return _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('daily_menu')
        .doc(dateKey)
        .snapshots();
  }

  // ---------- Hostel settings ----------

  Future<void> updateHostelSettings({
    required String hostelId,
    required String name,
    required String address,
    required String city,
    required String phone,
    required String gstin,
    required bool gstEnabled,
  }) async {
    await _firestore.collection('hostels').doc(hostelId).update({
      'name': name,
      'address': address,
      'city': city,
      'phone': phone.isEmpty ? '' : '+91$phone',
      'gstin': gstin,
      'gstEnabled': gstEnabled,
    });
  }

  // ---------- Expense budgets ----------

  Future<void> saveBudget({
    required String hostelId,
    required String period,
    required Map<String, int> budgets,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('expense_budgets')
        .doc(period)
        .set(budgets.map((k, v) => MapEntry(k, v)));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchBudget({
    required String hostelId,
    required String period,
  }) {
    return _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('expense_budgets')
        .doc(period)
        .snapshots();
  }

  // ---------- Notice board ----------

  Future<void> addNotice({
    required String hostelId,
    required String title,
    required String body,
    String targetAudience = 'all',
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('notices')
        .add({
      'title': title.trim(),
      'body': body.trim(),
      'targetAudience': targetAudience,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchNotices(String hostelId) {
    return _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('notices')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteNotice({
    required String hostelId,
    required String noticeId,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('notices')
        .doc(noticeId)
        .delete();
  }

  // ---------- Checkout requests ----------

  Future<void> requestCheckout({
    required String hostelId,
    required String guestId,
    required String guestName,
    required String roomNumber,
    DateTime? expectedMoveOut,
    String note = '',
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('checkout_requests')
        .add({
      'guestId': guestId,
      'guestName': guestName,
      'roomNumber': roomNumber,
      'note': note.trim(),
      'expectedMoveOut':
          expectedMoveOut != null ? Timestamp.fromDate(expectedMoveOut) : null,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'processedAt': null,
    });
  }

  // Pending checkout requests for owner dashboard
  Stream<QuerySnapshot<Map<String, dynamic>>> watchCheckoutRequests(
      String hostelId) {
    return _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('checkout_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // All checkout requests for a specific tenant (sorted in-app)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTenantCheckoutRequests({
    required String hostelId,
    required String guestId,
  }) {
    return _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('checkout_requests')
        .where('guestId', isEqualTo: guestId)
        .snapshots();
  }

  Future<void> approveCheckout({
    required String hostelId,
    required String requestId,
    required String guestId,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('checkout_requests')
        .doc(requestId)
        .update({
      'status': 'approved',
      'processedAt': FieldValue.serverTimestamp(),
    });
    await markGuestExited(hostelId: hostelId, guestId: guestId);
  }

  Future<void> denyCheckout({
    required String hostelId,
    required String requestId,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('checkout_requests')
        .doc(requestId)
        .update({
      'status': 'denied',
      'processedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Inventory ──────────────────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> watchInventory(
          String hostelId) =>
      _firestore
          .collection('hostels')
          .doc(hostelId)
          .collection('inventory')
          .orderBy('name')
          .snapshots();

  Future<void> addInventoryItem({
    required String hostelId,
    required String name,
    required String category,
    required String unit,
    required int currentStock,
    required int maxStock,
    int? daysLeft,
    String? nextDelivery,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('inventory')
        .add({
      'name': name.trim(),
      'category': category,
      'unit': unit,
      'currentStock': currentStock,
      'maxStock': maxStock,
      'daysLeft': ?daysLeft,
      'nextDelivery': ?nextDelivery,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateInventoryStock({
    required String hostelId,
    required String itemId,
    required int currentStock,
    int? daysLeft,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('inventory')
        .doc(itemId)
        .update({
      'currentStock': currentStock,
      'daysLeft': ?daysLeft,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRestockHistory(
          String hostelId) =>
      _firestore
          .collection('hostels')
          .doc(hostelId)
          .collection('restock_history')
          .orderBy('addedAt', descending: true)
          .snapshots();

  Future<void> addRestockEntry({
    required String hostelId,
    required String itemName,
    required String category,
    required int quantityAdded,
    required String unit,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('restock_history')
        .add({
      'itemName': itemName.trim(),
      'category': category,
      'quantityAdded': quantityAdded,
      'unit': unit,
      'status': 'completed',
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Service Marketplace ────────────────────────────────────────────────

  Future<String> bookService({
    required String hostelId,
    required String guestId,
    required String guestName,
    required String serviceName,
    required String category,
    required String price,
    required String slot,
    required String bookingDate,
  }) async {
    final ref = await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('service_bookings')
        .add({
      'guestId': guestId,
      'guestName': guestName,
      'serviceName': serviceName,
      'category': category,
      'price': price,
      'slot': slot,
      'bookingDate': bookingDate,
      'status': 'pending',
      'bookedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyServiceBookings({
    required String hostelId,
    required String guestId,
  }) =>
      _firestore
          .collection('hostels')
          .doc(hostelId)
          .collection('service_bookings')
          .where('guestId', isEqualTo: guestId)
          .orderBy('bookedAt', descending: true)
          .snapshots();

  // ── Wallet & Transactions ──────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUserTransactions(
          String uid) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots();

  // ── Referrals ──────────────────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUserReferrals(
          String uid) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('referrals')
          .orderBy('createdAt', descending: true)
          .snapshots();

  Future<String> ensureReferralCode(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final existing = doc.data()?['referralCode'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;
    final code = _makeReferralCode();
    await _firestore.collection('users').doc(uid).update({'referralCode': code});
    return code;
  }

  // ── Equipment ──────────────────────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> watchEquipment(String hostelId) =>
      _firestore
          .collection('hostels')
          .doc(hostelId)
          .collection('equipment')
          .orderBy('createdAt', descending: false)
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRepairs({
    required String hostelId,
    required String equipmentId,
  }) =>
      _firestore
          .collection('hostels')
          .doc(hostelId)
          .collection('equipment')
          .doc(equipmentId)
          .collection('repairs')
          .orderBy('date', descending: true)
          .snapshots();

  Future<void> addEquipment({
    required String hostelId,
    required String name,
    required String category,
    String model = '',
    String serialNumber = '',
    String machineNumber = '',
    DateTime? purchaseDate,
    int purchasePrice = 0,
    DateTime? warrantyExpiry,
    String notes = '',
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('equipment')
        .add({
      'name': name.trim(),
      'category': category,
      'model': model.trim(),
      'serialNumber': serialNumber.trim(),
      'machineNumber': machineNumber.trim(),
      'purchaseDate': purchaseDate != null ? Timestamp.fromDate(purchaseDate) : null,
      'purchasePrice': purchasePrice,
      'warrantyExpiry': warrantyExpiry != null ? Timestamp.fromDate(warrantyExpiry) : null,
      'status': 'working',
      'totalRepairCost': 0,
      'repairCount': 0,
      'notes': notes.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateEquipment({
    required String hostelId,
    required String equipmentId,
    required String name,
    required String category,
    String model = '',
    String serialNumber = '',
    String machineNumber = '',
    DateTime? purchaseDate,
    int purchasePrice = 0,
    DateTime? warrantyExpiry,
    String notes = '',
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('equipment')
        .doc(equipmentId)
        .update({
      'name': name.trim(),
      'category': category,
      'model': model.trim(),
      'serialNumber': serialNumber.trim(),
      'machineNumber': machineNumber.trim(),
      'purchaseDate': purchaseDate != null ? Timestamp.fromDate(purchaseDate) : null,
      'purchasePrice': purchasePrice,
      'warrantyExpiry': warrantyExpiry != null ? Timestamp.fromDate(warrantyExpiry) : null,
      'notes': notes.trim(),
    });
  }

  Future<void> updateEquipmentStatus({
    required String hostelId,
    required String equipmentId,
    required String status,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('equipment')
        .doc(equipmentId)
        .update({'status': status});
  }

  Future<void> deleteEquipment({
    required String hostelId,
    required String equipmentId,
  }) async {
    await _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('equipment')
        .doc(equipmentId)
        .delete();
  }

  Future<void> logRepair({
    required String hostelId,
    required String equipmentId,
    required DateTime date,
    required int amount,
    required String description,
    required String paidBy,
  }) async {
    final equipRef = _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('equipment')
        .doc(equipmentId);
    final repairRef = equipRef.collection('repairs').doc();
    final batch = _firestore.batch();
    batch.set(repairRef, {
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'description': description.trim(),
      'paidBy': paidBy.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(equipRef, {
      'totalRepairCost': FieldValue.increment(amount),
      'repairCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> deleteRepair({
    required String hostelId,
    required String equipmentId,
    required String repairId,
    required int amount,
  }) async {
    final equipRef = _firestore
        .collection('hostels')
        .doc(hostelId)
        .collection('equipment')
        .doc(equipmentId);
    final repairRef = equipRef.collection('repairs').doc(repairId);
    final batch = _firestore.batch();
    batch.delete(repairRef);
    batch.update(equipRef, {
      'totalRepairCost': FieldValue.increment(-amount),
      'repairCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  String _makeReferralCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    final suffix =
        List.generate(4, (_) => chars[rnd.nextInt(chars.length)]).join();
    return 'SANCT-$suffix';
  }
}
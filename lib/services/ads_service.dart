import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdsService {
  final _db = FirebaseFirestore.instance;

  static const adCategories = [
    'Food & Dining',
    'Technology',
    'Fashion & Lifestyle',
    'Health & Fitness',
    'Education',
    'Finance',
    'Travel',
    'Entertainment',
    'Home & Living',
    'Other',
  ];

  static const adTypes = ['image', 'video', 'animation'];
  static const genderOptions = ['all', 'male', 'female', 'other'];
  static const durationOptions = [30, 60];

  // ── Fetch ──────────────────────────────────────────────────────────────────

  /// Returns one ad best matching the user's profile, or null if none available.
  Future<Map<String, dynamic>?> fetchMatchingAd({
    String gender = 'other',
    int age = 25,
    String city = '',
  }) async {
    final now = Timestamp.now();
    final snap = await _db.collection('ads').where('status', isEqualTo: 'active').get();

    final matching = snap.docs.where((d) {
      final data = d.data();
      // End date
      final end = data['endDate'] as Timestamp?;
      if (end != null && end.millisecondsSinceEpoch < now.millisecondsSinceEpoch) {
        return false;
      }
      // Budget
      if ((data['remainingBudget'] as num?)?.toInt() == 0) return false;
      // Gender
      final tGender = data['targetGender'] as String? ?? 'all';
      if (tGender != 'all' && tGender != gender) return false;
      // Age
      final minAge = (data['targetAgeMin'] as num?)?.toInt() ?? 0;
      final maxAge = (data['targetAgeMax'] as num?)?.toInt() ?? 120;
      if (age < minAge || age > maxAge) return false;
      // City
      final tCity = (data['targetCity'] as String? ?? '').toLowerCase().trim();
      if (tCity.isNotEmpty && tCity != city.toLowerCase().trim()) return false;
      return true;
    }).toList();

    if (matching.isEmpty) return null;
    matching.shuffle(Random());
    final doc = matching.first;
    return {'id': doc.id, ...doc.data()};
  }

  // ── Tracking ───────────────────────────────────────────────────────────────

  Future<void> recordImpression({
    required String adId,
    required String uid,
    String gender = 'other',
    int age = 25,
    String city = '',
  }) async {
    final batch = _db.batch();
    batch.update(_db.collection('ads').doc(adId), {
      'totalImpressions': FieldValue.increment(1),
    });
    batch.set(_db.collection('ad_events').doc(), {
      'adId': adId,
      'userId': uid,
      'eventType': 'impression',
      'userGender': gender,
      'userAge': age,
      'userCity': city,
      'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> recordClick({required String adId, required String uid}) async {
    final batch = _db.batch();
    batch.update(_db.collection('ads').doc(adId), {
      'totalClicks': FieldValue.increment(1),
    });
    batch.set(_db.collection('ad_events').doc(), {
      'adId': adId,
      'userId': uid,
      'eventType': 'click',
      'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Records a full ad view. Deducts CPM cost from ad budget.
  /// Does NOT credit the user wallet — call HostelService.recordAdWatched separately.
  Future<void> recordCompletion({
    required String adId,
    required String uid,
  }) async {
    final adSnap = await _db.collection('ads').doc(adId).get();
    final cpm = (adSnap.data()?['cpm'] as num?)?.toDouble() ?? 2000;
    final cost = (cpm / 1000).ceil();

    final batch = _db.batch();
    batch.update(_db.collection('ads').doc(adId), {
      'completions': FieldValue.increment(1),
      'remainingBudget': FieldValue.increment(-cost),
    });
    batch.set(_db.collection('ad_events').doc(), {
      'adId': adId,
      'userId': uid,
      'eventType': 'complete',
      'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // ── Admin streams ──────────────────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllAds() =>
      _db.collection('ads').orderBy('createdAt', descending: true).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAdEventsSince(DateTime since) =>
      _db
          .collection('ad_events')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .snapshots();

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> createAd({
    required String title,
    required String advertiserName,
    required String type,
    required String mediaUrl,
    required int duration,
    required String targetGender,
    required int targetAgeMin,
    required int targetAgeMax,
    required String targetCity,
    required String category,
    required int budget,
    required int cpm,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _db.collection('ads').add({
      'title': title.trim(),
      'advertiserName': advertiserName.trim(),
      'type': type,
      'mediaUrl': mediaUrl.trim(),
      'duration': duration,
      'targetGender': targetGender,
      'targetAgeMin': targetAgeMin,
      'targetAgeMax': targetAgeMax,
      'targetCity': targetCity.trim(),
      'category': category,
      'status': 'active',
      'budget': budget,
      'remainingBudget': budget,
      'cpm': cpm,
      'totalImpressions': 0,
      'totalClicks': 0,
      'completions': 0,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAdStatus({required String adId, required String status}) async {
    await _db.collection('ads').doc(adId).update({'status': status});
  }

  Future<void> deleteAd(String adId) async {
    await _db.collection('ads').doc(adId).delete();
  }
}

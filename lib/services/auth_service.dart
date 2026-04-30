import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// AuthService wraps all Firebase Auth + user-doc logic in one place.
// This way our UI screens don't need to know any Firebase details —
// they just call these methods.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign up a new user with email + password, then create their user doc.
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Store the name on the Firebase Auth user
    await credential.user?.updateDisplayName(name);
    // Create the Firestore doc (default role = "guest")
    await _createUserDocIfMissing(credential.user!, name: name);
  }

  // Sign in existing user with email + password
  Future<void> signInWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Safety: make sure the user doc exists
    await _createUserDocIfMissing(credential.user!);
  }

  // Sign in with Google. On Flutter web we use signInWithPopup.
  // On Android/iOS, Google sign-in needs extra native setup — we'll
  // add that in a later week. For now it only works on web.
  Future<void> signInWithGoogle() async {
    if (!kIsWeb) {
      throw UnsupportedError(
        'Google sign-in on mobile needs extra setup. Use email/password on mobile for now.',
      );
    }
    final provider = GoogleAuthProvider();
    final credential = await _auth.signInWithPopup(provider);
    await _createUserDocIfMissing(
      credential.user!,
      name: credential.user!.displayName,
    );
  }

  // Sign out the current user
  Future<void> signOut() => _auth.signOut();

  // Private helper: create the user doc in Firestore if it doesn't exist yet.
  Future<void> _createUserDocIfMissing(User user, {String? name}) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    if (snapshot.exists) return;
    await docRef.set({
      'uid': user.uid,
      'email': user.email,
      'name': name ?? user.displayName ?? '',
      'role': 'guest',
      'hostelId': null,
      'hostelIds': [],
      'tenantHostelId': null,
      'tenantGuestId': null,
      'referralCode': _generateReferralCode(),
      'referredBy': null,
      'wallet': {'available': 0, 'bonus': 0, 'pending': 0},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _generateReferralCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
  // Send a password-reset email via Firebase Auth.
// Firebase handles the email template and the reset link.
Future<void> sendPasswordResetEmail(String email) async {
  await _auth.sendPasswordResetEmail(email: email.trim());
}
}
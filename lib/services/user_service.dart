// lib/services/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users');

  /// Get user profile by UID
  Future<AppUser?> getUserProfile(String uid) async {
    try {
      final snap = await _col.doc(uid).get();
      if (!snap.exists) return null;
      return AppUser.fromFirestore(snap);
    } catch (e) {
      return null;
    }
  }

  /// Stream user profile by UID
  Stream<AppUser?> streamUserProfile(String uid) {
    return _col.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return AppUser.fromFirestore(snap);
    });
  }

  /// Upsert (create or update) a user profile
  Future<void> upsertProfile(String uid, Map<String, dynamic> data) async {
    await _col.doc(uid).set(data, SetOptions(merge: true));
  }

  /// Reserve a username (mark it as taken)
  Future<bool> reserveUsername(String username) async {
    try {
      final reserved = _db.collection('reserved_usernames').doc(username);
      await reserved.set({'reserved': true});
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final snap = await _db.collection('reserved_usernames').doc(username).get();
      return !snap.exists;
    } catch (e) {
      return false;
    }
  }
}


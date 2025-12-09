// lib/services/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  static CollectionReference<Map<String, dynamic>> get _usernames =>
      _db.collection('usernames');

  /* ────────────────────────────────────────────────
     NORMALIZER: Adds id + fixes photo field names
     ──────────────────────────────────────────────── */

  static Map<String, dynamic>? _normalizeUser(
      String id, Map<String, dynamic>? raw) {
    if (raw == null) return null;

    // Normalize photo field from many possible names
    final dynamicPhoto = raw["photo"] ??
        raw["photoURL"] ??
        raw["photoUrl"] ??
        raw["profilePicture"];

    final photo = dynamicPhoto?.toString();

    // Ensure usernameLower exists if possible
    final username = raw["username"]?.toString();
    final usernameLower =
        raw["usernameLower"]?.toString() ?? username?.toLowerCase();

    return {
      "id": id,
      ...raw,
      if (photo != null && photo.isNotEmpty) "photo": photo,
      if (usernameLower != null) "usernameLower": usernameLower,
    };
  }

  /* ────────────────────────────────────────────────
     GET USER
     ──────────────────────────────────────────────── */

  static Future<Map<String, dynamic>?> getUser(String uid) async {
    if (uid.isEmpty) return null; // ← prevents path error

    final doc = await _users.doc(uid).get();
    return _normalizeUser(doc.id, doc.data());
  }

  /* ────────────────────────────────────────────────
     UPSERT PROFILE
     ──────────────────────────────────────────────── */

  static Future<void> upsertProfile(
      String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).set(data, SetOptions(merge: true));
  }

  /* ────────────────────────────────────────────────
     USERNAME SYSTEM
     ──────────────────────────────────────────────── */

  static Future<bool> usernameAvailable(String handle) async {
    handle = handle.trim().toLowerCase();
    if (handle.isEmpty) return false;

    final doc = await _usernames.doc(handle).get();
    return !doc.exists;
  }

  static Future<void> reserveUsername(String handle) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Not logged in.");

    handle = handle.trim().toLowerCase();
    if (handle.isEmpty) throw Exception("Invalid username.");

    await _usernames.doc(handle).set({
      "uid": user.uid,
      "reservedAt": FieldValue.serverTimestamp(),
    });
  }

  static Future<void> changeUsername(String newHandle) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Not logged in.");

    newHandle = newHandle.trim().toLowerCase();
    if (newHandle.isEmpty) throw Exception("Invalid username.");

    final userDoc = await _users.doc(user.uid).get();
    final data = userDoc.data();
    final oldHandle = data?["usernameLower"];

    if (oldHandle == newHandle) return;

    if ((await _usernames.doc(newHandle).get()).exists) {
      throw Exception("That username is taken.");
    }

    await _db.runTransaction((transaction) async {
      if (oldHandle != null) {
        transaction.delete(_usernames.doc(oldHandle));
      }

      transaction.set(_usernames.doc(newHandle),
          {"uid": user.uid, "reservedAt": FieldValue.serverTimestamp()});

      transaction.set(
        _users.doc(user.uid),
        {
          "username": newHandle,
          "usernameLower": newHandle,
        },
        SetOptions(merge: true),
      );
    });
  }

  /* ────────────────────────────────────────────────
     SEARCH USERS
     ──────────────────────────────────────────────── */

  static Stream<List<Map<String, dynamic>>> searchUsers(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const Stream.empty();

    return _users
        .where("usernameLower", isGreaterThanOrEqualTo: q)
        .where("usernameLower", isLessThanOrEqualTo: "$q\uf8ff")
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => _normalizeUser(d.id, d.data()))
            .whereType<Map<String, dynamic>>()
            .toList());
  }
}

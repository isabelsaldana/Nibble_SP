// lib/user_service.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

// ------------------------------------------------------------------------
// --- NEW: APP USER MODEL ---
// ------------------------------------------------------------------------

class AppUser {
  final String id;
  final String? username; // Firestore field
  final String displayName; // FirebaseAuth field, mirrored in Firestore
  final String? photoURL; // FirebaseAuth field, mirrored in Firestore

  AppUser({
    required this.id,
    this.username,
    required this.displayName,
    this.photoURL,
  });

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    
    // Fallback logic for displayName
    String name = (data['displayName'] ?? '').toString();
    if (name.isEmpty) {
      name = data['username']?.toString() ?? 'User ${doc.id.substring(0, 4)}';
    }

    return AppUser(
      id: doc.id,
      username: data['username']?.toString(),
      displayName: name,
      photoURL: data['photoURL']?.toString(),
    );
  }
}


class UserService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  String get uid {
    if (_auth.currentUser == null) {
      throw Exception("User not authenticated.");
    }
    return _auth.currentUser!.uid;
  }

  // ------------------------------------------------------------------------
  // --- NEW: FETCHING & CURRENT USER HELPERS ---
  // ------------------------------------------------------------------------

  String getCurrentUserId() {
    return _auth.currentUser?.uid ?? '';
  }

  /// Fetches a single user profile by UID.
  Future<AppUser> getUserProfile(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) {
      // Create a fallback AppUser if the document doesn't exist
      return AppUser(
        id: userId,
        displayName: 'Deleted User',
        photoURL: null,
      );
    }
    return AppUser.fromFirestore(doc);
  }

  /// Searches for users by display name or username.
  /// NOTE: This search uses limited Firestore prefix queries.
  Future<List<AppUser>> searchUsers(String query) async {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];

    try {
      // Basic prefix search on 'displayName' (requires index)
      final snapshot = await _db
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: q)
          .where('displayName', isLessThan: '$q\uf8ff')
          .limit(20)
          .get();

      final results = snapshot.docs.map(AppUser.fromFirestore).toList();

      // Check for exact username match as a fallback (uses 'usernames' collection)
      if (results.isEmpty) {
        final usernameSnap = await _db.collection('usernames').doc(q).get();
        if (usernameSnap.exists) {
          final targetUid = (usernameSnap.data()?['uid'] as String?) ?? '';
          if (targetUid.isNotEmpty) {
            final user = await getUserProfile(targetUid);
            return [user];
          }
        }
      }
      
      return results;
    } catch (e) {
      // In a real app, log error. For now, return empty.
      return [];
    }
  }

  // ------------------------------------------------------------------------
  // --- NEW: FOLLOW / UNFOLLOW METHODS (MOCK IMPLEMENTATION FOR UI) ---
  // ------------------------------------------------------------------------

  /// Checks if the current user is following the target user. (MOCK LOGIC)
  Future<bool> isFollowing(String targetUid) async {
    // Replace this with your actual Firestore check
    await Future.delayed(const Duration(milliseconds: 100));
    // Simple mock: User is following themselves (for testing), otherwise not.
    return targetUid == getCurrentUserId();
  }

  /// Toggles the follow state. (MOCK LOGIC)
  Future<void> toggleFollow(String targetUid, bool isCurrentlyFollowing) async {
    if (_auth.currentUser == null) throw Exception("Authentication required.");
    // Replace with actual batch write/transaction to update followers/following collections
    await Future.delayed(const Duration(milliseconds: 200));
    print('${_auth.currentUser!.uid} ${isCurrentlyFollowing ? "unfollowed" : "followed"} $targetUid');
  }

  // ------------------------------------------------------------------------
  // --- ORIGINAL USER METHODS (KEPT AS IS) ---
  // ------------------------------------------------------------------------

  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Future<void> upsertProfile(Map<String, dynamic> data) async {
    final ref = _db.collection('users').doc(uid);
    data['updatedAt'] = FieldValue.serverTimestamp();
    data.putIfAbsent('createdAt', () => FieldValue.serverTimestamp());
    await ref.set(data, SetOptions(merge: true));

    if (data['displayName'] is String) {
      await _auth.currentUser!.updateDisplayName(data['displayName'] as String);
    }
  }

  /// Reserve a handle and bind it to the caller's uid (matches your Firestore rules)
  Future<void> reserveUsername(String handleLower) async {
    final usernamesRef = _db.collection('usernames').doc(handleLower);
    final userRef = _db.collection('users').doc(uid);

    await _db.runTransaction((tx) async {
      final existing = await tx.get(usernamesRef);
      if (existing.exists) {
        throw StateError('That username is taken.');
      }
      tx.set(usernamesRef, {
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(userRef, {
        'username': handleLower,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Upload cropped bytes from web/mobile. Cropper returns PNG by default.
  Future<String> uploadProfilePhotoBytes(
    Uint8List data, {
    String contentType = 'image/png',
  }) async {
    final ref = _storage.ref('users/$uid/profile.png');
    final meta = SettableMetadata(
      contentType: contentType,
      cacheControl: 'public,max-age=3600',
    );
    final task = await ref.putData(data, meta);
    final url = await task.ref.getDownloadURL();

    // Save to Firestore + FirebaseAuth profile
    await _db.collection('users').doc(uid).set({
      'photoURL': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _auth.currentUser!.updatePhotoURL(url);

    return url;
  }
}
// lib/user_service.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  String get uid => _auth.currentUser!.uid;

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

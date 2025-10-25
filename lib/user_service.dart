import 'dart:io';
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

  Future<void> upsertProfile({
    required String displayName,
    required String username,
    required String bio,
  }) async {
    final ref = _db.collection('users').doc(uid);
    await ref.set({
      'displayName': displayName,
      'username': username,
      'bio': bio,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _auth.currentUser!.updateDisplayName(displayName);
  }

  Future<String?> uploadProfilePhoto(File file) async {
    final path = 'users/$uid/profile.jpg';
    final task = await _storage.ref(path).putFile(file);
    final url = await task.ref.getDownloadURL();
    await _db.collection('users').doc(uid).set({
      'photoURL': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _auth.currentUser!.updatePhotoURL(url);
    return url;
  }
}

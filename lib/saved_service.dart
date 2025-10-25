import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SavedService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get uid => _auth.currentUser!.uid;

  Future<void> saveRecipe(String recipeId) async {
    await _db.collection('users').doc(uid)
      .collection('savedRecipes').doc(recipeId).set({
        'createdAt': FieldValue.serverTimestamp(),
      });
  }

  Future<void> unsaveRecipe(String recipeId) async {
    await _db.collection('users').doc(uid)
      .collection('savedRecipes').doc(recipeId).delete();
  }

  Stream<bool> isSaved(String recipeId) {
    return _db.collection('users').doc(uid)
      .collection('savedRecipes').doc(recipeId)
      .snapshots().map((doc) => doc.exists);
  }

  Stream<List<String>> savedIds() {
    return _db.collection('users').doc(uid)
      .collection('savedRecipes')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((q) => q.docs.map((d) => d.id).toList());
  }
}

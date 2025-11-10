import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recipe.dart';

class RecipeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('recipes');

  CollectionReference<Map<String, dynamic>> get _trashCol =>
      _db.collection('deleted_recipes');

  /// Create a new recipe document and return its Firestore ID.
  /// Requires the current user's uid so we can store `authorId`.
  Future<String> create(Recipe recipe, String uid) async {
    final doc = await _col.add({
      ...recipe.toMap(),
      'authorId': uid, // 👈 owner of this recipe, matches rules (authorId == request.auth.uid)
      // for feed/profile ordering
      'createdAt': FieldValue.serverTimestamp(),
      'localCreatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    return doc.id;
  }

  /// Patch update on an existing recipe.
  Future<void> update(String id, Map<String, dynamic> data) {
    return _col.doc(id).update(data);
  }

  /// Hard delete from main collection (usually we prefer softDelete).
  Future<void> deleteHard(String id) {
    return _col.doc(id).delete();
  }

  /// Soft delete:
  ///  - copy recipe to deleted_recipes with deletedAt
  ///  - remove from main recipes collection
  Future<void> softDelete(Recipe recipe) async {
    final batch = _db.batch();

    final srcRef = _col.doc(recipe.id);
    final dstRef = _trashCol.doc(recipe.id);

    batch.set(dstRef, {
      ...recipe.toMap(),
      'deletedAt': FieldValue.serverTimestamp(),
    });

    batch.delete(srcRef);

    await batch.commit();
  }

  /// Stream for the public feed (only public recipes).
  Stream<List<Recipe>> publicFeed() {
    return _col
        .where('isPublic', isEqualTo: true)
        .orderBy('localCreatedAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => Recipe.fromFirestore(doc)).toList(),
        );
  }

  /// Stream for "My Recipes" on the profile page.
  /// Uses authorId + localCreatedAt, matching your Firestore index.
  Stream<List<Recipe>> userRecipes(String uid) {
    return _col
        .where('authorId', isEqualTo: uid)
        .orderBy('localCreatedAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => Recipe.fromFirestore(doc)).toList(),
        );
  }

  /// Stream for the Trash page (deleted_recipes for this user).
  Stream<List<Recipe>> trashForUser(String uid) {
    return _trashCol
        .where('authorId', isEqualTo: uid)
        .orderBy('deletedAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => Recipe.fromFirestore(doc)).toList(),
        );
  }

  /// Permanently delete from trash.
  Future<void> deleteForeverFromTrash(String id) {
    return _trashCol.doc(id).delete();
  }

  /// Restore a recipe from trash back to the main collection.
  Future<void> restoreFromTrash(String id) async {
    final doc = await _trashCol.doc(id).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final restored = Map<String, dynamic>.from(data)..remove('deletedAt');

    await _col.doc(id).set(restored, SetOptions(merge: true));
    await _trashCol.doc(id).delete();
  }

  // ---------------------------------------------------------------------------
  // 🔁 Compatibility wrappers so existing code keeps working
  //    (trash_page.dart + my_recipes_section.dart)
  // ---------------------------------------------------------------------------

  /// Old name used in trash_page.dart: svc.deletedRecipes(uid)
  Stream<List<Recipe>> deletedRecipes(String uid) => trashForUser(uid);

  /// Old name used in trash_page.dart: svc.deleteFromTrash(id)
  Future<void> deleteFromTrash(String id) => deleteForeverFromTrash(id);

  /// Old name used in my_recipes_section.dart: svc.deleteWithBackup(recipe)
  Future<void> deleteWithBackup(Recipe recipe) => softDelete(recipe);
}

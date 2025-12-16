import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/recipe.dart';
import '../utils/search_index.dart';

class RecipeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('recipes');
  CollectionReference<Map<String, dynamic>> get _trashCol =>
      _db.collection('deleted_recipes');

  // ---------------------------
  // helpers
  // ---------------------------
  List<String> _stringList(dynamic v) {
    if (v is List) {
      return v
          .where((e) => e != null)
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (v is String && v.trim().isNotEmpty) return [v.trim()];
    return <String>[];
  }

  List<String> _stepsToList(dynamic v) {
    if (v is List) {
      return v
          .where((e) => e != null)
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (v is String && v.trim().isNotEmpty) return [v.trim()];
    return <String>[];
  }

  /// ✅ returns List<String> (tokens)
  List<String> _buildSearchIndexFromMap(Map<String, dynamic> data) {
    final title = (data['title'] ?? '').toString();
    final description = (data['description'] ?? '').toString();
    final tags = _stringList(data['tags']);
    final ingredients = _stringList(data['ingredients']);
    final steps = _stepsToList(data['steps']);

    return SearchIndex.buildRecipeIndex(
      title: title,
      description: description,
      tags: tags,
      ingredients: ingredients,
      steps: steps,
    );
  }

  /// Create
  Future<String> create(Recipe recipe, String uid) async {
    final base = recipe.toMap();

    final doc = await _col.add({
      ...base,
      'authorId': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'localCreatedAt': DateTime.now().millisecondsSinceEpoch,
      'searchIndex': _buildSearchIndexFromMap(base),
    });

    return doc.id;
  }

  /// Update (rebuild searchIndex when needed)
  Future<void> update(String id, Map<String, dynamic> data) async {
    if (data.isEmpty) return;

    const indexKeys = {'title', 'description', 'tags', 'ingredients', 'steps'};
    final touchesIndex = data.keys.any((k) => indexKeys.contains(k));

    if (!touchesIndex) {
      return _col.doc(id).update(data);
    }

    final snap = await _col.doc(id).get();
    final current = snap.data() ?? <String, dynamic>{};
    final merged = <String, dynamic>{...current, ...data};

    final patch = <String, dynamic>{
      ...data,
      'searchIndex': _buildSearchIndexFromMap(merged),
    };

    return _col.doc(id).update(patch);
  }

  Future<void> deleteHard(String id) => _col.doc(id).delete();

  /// ✅ Soft delete: copy data into deleted_recipes, then delete from recipes
  /// (keeps deletedAt for sorting trash)
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

  Stream<List<Recipe>> publicFeed() {
    return _col
        .where('isPublic', isEqualTo: true)
        .orderBy('localCreatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Recipe.fromFirestore(doc)).toList());
  }

  Stream<List<Recipe>> userRecipes(String uid) {
    return _col
        .where('authorId', isEqualTo: uid)
        .orderBy('localCreatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Recipe.fromFirestore(doc)).toList());
  }

  Stream<List<Recipe>> trashForUser(String uid) {
    return _trashCol
        .where('authorId', isEqualTo: uid)
        .orderBy('deletedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Recipe.fromFirestore(doc)).toList());
  }

  /// ✅ permanently deletes from deleted_recipes
  Future<void> deleteForeverFromTrash(String id) => _trashCol.doc(id).delete();

  /// ✅ restores from deleted_recipes -> recipes
  Future<void> restoreFromTrash(String id) async {
    final doc = await _trashCol.doc(id).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final restored = Map<String, dynamic>.from(data)..remove('deletedAt');

    // ✅ ensure profile sorting works (your profile orders by localCreatedAt)
    restored['localCreatedAt'] ??= DateTime.now().millisecondsSinceEpoch;

    // ✅ ensure searchIndex exists (optional but helps if your UI relies on it)
    restored['searchIndex'] ??= _buildSearchIndexFromMap(restored);

    await _col.doc(id).set(restored, SetOptions(merge: true));
    await _trashCol.doc(id).delete();
  }

  // Compatibility wrappers
  Stream<List<Recipe>> deletedRecipes(String uid) => trashForUser(uid);

  // NOTE: keep this if other files still call deleteFromTrash
  Future<void> deleteFromTrash(String id) => deleteForeverFromTrash(id);

  Future<void> deleteWithBackup(Recipe recipe) => softDelete(recipe);
}

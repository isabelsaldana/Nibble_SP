// lib/services/recipe_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recipe.dart';

class RecipeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('recipes');

  CollectionReference<Map<String, dynamic>> get _trashCol =>
      _db.collection('deleted_recipes');

  /// Create a new recipe document and return its Firestore ID.
  Future<String> create(Map<String, dynamic> recipeMap, String uid) async {
    final doc = await _col.add({
      ...recipeMap,
      'authorId': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'localCreatedAt': DateTime.now().millisecondsSinceEpoch,
    });
    return doc.id;
  }

  Future<void> update(String id, Map<String, dynamic> data) =>
      _col.doc(id).update(data);

  Future<void> deleteHard(String id) => _col.doc(id).delete();

  Future<void> softDelete(Map<String, dynamic> recipeMap, String id) async {
    final batch = _db.batch();
    final srcRef = _col.doc(id);
    final dstRef = _trashCol.doc(id);

    batch.set(dstRef, {
      ...recipeMap,
      'deletedAt': FieldValue.serverTimestamp(),
    });

    batch.delete(srcRef);
    await batch.commit();
  }

  Stream<List<Map<String, dynamic>>> publicFeedRaw({int limit = 200}) {
    return _col
        .where('isPublic', isEqualTo: true)
        .orderBy('localCreatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Returns public feed as Recipe model objects.
  Stream<List<Recipe>> publicFeed({int limit = 200}) {
    return _col
        .where('isPublic', isEqualTo: true)
        .orderBy('localCreatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Recipe.fromFirestore(
                d as DocumentSnapshot<Map<String, dynamic>>))
            .toList());
  }

  Stream<List<Map<String, dynamic>>> userRecipesRaw(String uid) {
    return _col
        .where('authorId', isEqualTo: uid)
        .orderBy('localCreatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ---------------------------------------------------------------------------
  // Reviews / Ratings helpers
  // ---------------------------------------------------------------------------

  /// Add or update a review/rating. Uses userId as the document ID to ensure
  /// a user can only submit one rating per recipe.
  Future<void> addReview({
    required String recipeId,
    required String userId,
    required int rating, // 1..5
    String? text,
  }) {
    // Uses userId as the document ID for upsert (create or update)
    final ref = _col.doc(recipeId).collection('reviews').doc(userId); 
    final payload = {
      'userId': userId,
      'rating': rating,
      'text': text ?? '',
      // Note: Using 'updatedAt' is recommended when allowing updates
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(), 
    };
    // Use merge: true to update existing if doc(userId) already exists
    return ref.set(payload, SetOptions(merge: true)); 
  }

  /// Stream the current user's rating (as an integer) for a recipe.
  Stream<int> streamUserRating(String recipeId, String userId) {
    return _col
        .doc(recipeId)
        .collection('reviews')
        .doc(userId)
        .snapshots()
        .map((snap) {
      final data = snap.data();
      if (data == null || !data.containsKey('rating')) return 0;
      final rating = data['rating'];
      // Safely convert num/double back to int for the rating bar
      if (rating is int) return rating;
      if (rating is num) return rating.toInt();
      return 0;
    });
  }

  Stream<List<Map<String, dynamic>>> streamReviews(String recipeId) {
    return _col
        .doc(recipeId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'id': d.id, ...?d.data() as Map<String, dynamic>?})
            .toList());
  }

  /// Stream average rating and count for a recipe.
  Stream<Map<String, dynamic>> streamAverageRating(String recipeId) {
    return _col.doc(recipeId).collection('reviews').snapshots().map((snap) {
      final docs = snap.docs;
      if (docs.isEmpty) return {'avg': 0.0, 'count': 0};
      final ints = docs.map((d) {
        final r = d.data()['rating'];
        if (r is int) return r;
        if (r is num) return r.toInt();
        return 0;
      }).toList();
      final sum = ints.fold<int>(0, (p, n) => p + n);
      final avg = sum / ints.length;
      return {'avg': avg, 'count': ints.length};
    });
  }

  /// Convenience: raw deleted recipes as maps.
  Stream<List<Map<String, dynamic>>> deletedRecipesRaw() {
    return _trashCol
        .orderBy('deletedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Backwards-compatible API expected by some widgets. Returns model objects.
  Stream<List<Recipe>> userRecipes(String uid) {
    return _col
        .where('authorId', isEqualTo: uid)
        .orderBy('localCreatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Recipe.fromFirestore(
                d as DocumentSnapshot<Map<String, dynamic>>))
            .toList());
  }

  Future<void> deleteFromTrash(String id) => _trashCol.doc(id).delete();

  /// Returns deleted recipes as model objects for UI consumption.
  Stream<List<Recipe>> deleted_recipes(String uid) {
    return _trashCol
        .where('authorId', isEqualTo: uid)
        .orderBy('deletedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Recipe.fromFirestore(
                d as DocumentSnapshot<Map<String, dynamic>>))
            .toList());
  }

  /// Move recipe to trash (backup) and remove from main collection.
  /// Accepts either a `Recipe` instance or a map representation and moves it to trash.
  Future<void> deleteWithBackup(dynamic recipeOrMap) async {
    Map<String, dynamic> map;
    String id;
    if (recipeOrMap == null) throw ArgumentError.notNull('recipeOrMap');
    if (recipeOrMap is Map<String, dynamic>) {
      map = recipeOrMap;
      id = (map['id'] ?? '').toString();
    } else {
      // Try to handle a Recipe-like object by calling toMap and reading id
      try {
        final toMap = recipeOrMap.toMap();
        map = Map<String, dynamic>.from(toMap);
        id = (recipeOrMap.id ?? '').toString();
        map['id'] = id;
      } catch (e) {
        rethrow;
      }
    }
    if (id.isEmpty) throw ArgumentError('recipe must contain an id');
    await softDelete(map, id);
  }
}
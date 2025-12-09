// lib/services/recipe_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recipe.dart';

class RecipeService {
  static final _db = FirebaseFirestore.instance;

  /// Get a recipe by ID
  static Future<Recipe?> getRecipe(String id) async {
    final doc = await _db.collection('recipes').doc(id).get();
    return doc.exists ? Recipe.fromDoc(doc) : null;
  }
  /// ---------------------------------------------
  /// CREATE A NEW RECIPE
  /// ---------------------------------------------
  static Future<void> createRecipe(String id, Map<String, dynamic> data) async {
    final r = _normalizeRecipeData(data);
    await _db.collection('recipes').doc(id).set(r);
  }

  /// ---------------------------------------------
  /// UPDATE EXISTING RECIPE
  /// ---------------------------------------------
  static Future<void> updateRecipe(String id, Map<String, dynamic> data) async {
    final r = _normalizeRecipeData(data);
    await _db.collection('recipes').doc(id).update(r);
  }

  /// ---------------------------------------------
  /// INTERNAL NORMALIZATION
  /// Ensures titleLower, tagsLower, ingredientsLower are always correct
  /// ---------------------------------------------
  static Map<String, dynamic> _normalizeRecipeData(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);

    if (data.containsKey('title')) {
      normalized['titleLower'] =
          (data['title'] as String).toLowerCase().trim();
    }

    if (data.containsKey('tags')) {
      normalized['tagsLower'] =
          List<String>.from(data['tags'])
              .map((e) => e.toLowerCase().trim())
              .toList();
    }

    if (data.containsKey('ingredients')) {
      normalized['ingredientsLower'] =
          List<String>.from(data['ingredients'])
              .map((e) => e.toLowerCase().trim())
              .toList();
    }

    normalized['updatedAt'] = FieldValue.serverTimestamp();

    return normalized;
  }

  /// ---------------------------------------------
  /// RATING SYSTEM
  /// ---------------------------------------------
  static Future<void> rateRecipe({
    required String recipeId,
    required String userId,
    required int rating,
  }) async {
    final recipeRef = _db.collection('recipes').doc(recipeId);
    final ratingRef = recipeRef.collection('ratings').doc(userId);
    final userRatingRef = _db.collection('users').doc(userId).collection('ratings').doc(recipeId);

    return _db.runTransaction((transaction) async {
      // Retrieve recipe
      final recipeDoc = await transaction.get(recipeRef);
      if (!recipeDoc.exists) return;

      int currentCount = recipeDoc['ratingCount'] ?? 0;
      double currentAverage = (recipeDoc['averageRating'] ?? 0).toDouble();

      // Check if user has previously rated
      final existingRatingDoc = await transaction.get(ratingRef);

      if (existingRatingDoc.exists) {
        final oldRating = existingRatingDoc['rating'];
        final newTotal = (currentAverage * currentCount) - oldRating + rating;
        final newAverage = newTotal / currentCount;

        transaction.update(recipeRef, {
          'averageRating': newAverage,
          'updatedAt': FieldValue.serverTimestamp(),
        });

      } else {
        // New rating
        final newTotal = (currentAverage * currentCount) + rating;
        final newCount = currentCount + 1;
        final newAverage = newTotal / newCount;

        transaction.update(recipeRef, {
          'ratingCount': newCount,
          'averageRating': newAverage,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update rating document
      transaction.set(
        ratingRef,
        {
          'rating': rating,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      // Save into user's rating history
      transaction.set(
        userRatingRef,
        {
          'rating': rating,
          'recipeId': recipeId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  /// Get user's rating for a recipe
  static Future<int?> getUserRating(String recipeId, String userId) async {
    final doc = await _db.collection('recipes').doc(recipeId).collection('ratings').doc(userId).get();
    return doc.exists ? doc['rating'] : null;
  }

  /// ---------------------------------------------
  /// SEARCH HELPERS (used by search_page.dart)
  /// ---------------------------------------------
  static Stream<List<Recipe>> searchRecipes(String query) {
    final q = query.toLowerCase().trim();

    if (q.isEmpty) return const Stream.empty();

    return _db
        .collection('recipes')
        .where('titleLower', isGreaterThanOrEqualTo: q)
        .where('titleLower', isLessThanOrEqualTo: '$q\uf8ff')
        .snapshots()
        .map((snap) => snap.docs.map((e) => Recipe.fromDoc(e)).toList());
  }

  /// Search by tag (clickable chip)
  static Stream<List<Recipe>> searchByTag(String tag) {
    final t = tag.toLowerCase().trim();

    return _db
        .collection('recipes')
        .where('tagsLower', arrayContains: t)
        .snapshots()
        .map((snap) => snap.docs.map((e) => Recipe.fromDoc(e)).toList());
  }
    /// ------------------------------------------------------
  /// MOVE RECIPE TO TRASH (soft delete)
  /// ------------------------------------------------------
  static Future<void> moveToTrash(String recipeId) async {
    final recipeRef = _db.collection('recipes').doc(recipeId);
    final deletedRef = _db.collection('deleted_recipes').doc(recipeId);

    final doc = await recipeRef.get();
    if (!doc.exists) return;

    final data = doc.data()!..remove('ratings'); // remove subcollection pointer if needed

    // Copy to trash collection
    await deletedRef.set(data);

    // Remove from main recipes
    await recipeRef.delete();
  }

  /// ------------------------------------------------------
  /// RESTORE RECIPE FROM TRASH
  /// ------------------------------------------------------
  static Future<void> restoreFromTrash(String recipeId) async {
    final recipeRef = _db.collection('recipes').doc(recipeId);
    final deletedRef = _db.collection('deleted_recipes').doc(recipeId);

    final doc = await deletedRef.get();
    if (!doc.exists) return;

    final data = doc.data();

    // Restore recipe back to main recipes
    await recipeRef.set(data!);

    // Remove from trash
    await deletedRef.delete();
  }

  /// ------------------------------------------------------
  /// PERMANENTLY DELETE RECIPE FROM TRASH
  /// ------------------------------------------------------
  static Future<void> deleteFromTrash(String recipeId) async {
    final deletedRef = _db.collection('deleted_recipes').doc(recipeId);
    await deletedRef.delete();
  }

  /// ------------------------------------------------------
  /// STREAM DELETED RECIPES FOR ONE USER
  /// ------------------------------------------------------
  static Stream<List<Recipe>> deleted_recipes(String uid) {
    return _db
        .collection('deleted_recipes')
        .where('authorId', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Recipe.fromDoc(d)).toList());
  }

}

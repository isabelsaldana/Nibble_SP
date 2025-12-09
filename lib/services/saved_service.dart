import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/recipe.dart';

class SavedService {
  final _db = FirebaseFirestore.instance;

  /// Subcollection: users/{uid}/saved_recipes/{recipeId}
  CollectionReference<Map<String, dynamic>> _savedCol(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('saved_recipes');
  }

  /// Subcollection: users/{uid}/folders/{folderName}
  /// We use the folder name as the document id for simplicity.
  CollectionReference<Map<String, dynamic>> _folderCol(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('folders');
  }

  /// Stream: is this recipe saved by this user?
  Stream<bool> isSavedStream(String uid, String recipeId) {
    return _savedCol(uid)
        .doc(recipeId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  /// One-time check: is this recipe saved by this user?
  Future<bool> isSaved({
    required String uid,
    required String recipeId,
  }) async {
    final doc = await _savedCol(uid).doc(recipeId).get();
    return doc.exists;
  }

  /// Toggle saved / unsaved for a recipe in a given folder.
  ///
  /// On save:
  ///   - writes to saved_recipes
  ///   - ensures / updates a folder doc
  ///   - if folder cover is "auto", it becomes the latest recipe's image
  ///
  /// On unsave:
  ///   - delegates to [removeSaved] which recomputes recipeCount
  ///     and (for auto covers) the latest remaining image.
  Future<void> toggleSaved({
    required String uid,
    required Recipe recipe,
    String folder = 'General',
  }) async {
    final savedRef = _savedCol(uid).doc(recipe.id);
    final savedSnap = await savedRef.get();

    if (savedSnap.exists) {
      // -------- UNSAVE --------
      await removeSaved(uid: uid, recipeId: recipe.id);
      return;
    }

    // -------- SAVE --------
    final imageUrl =
        recipe.imageUrls.isNotEmpty ? recipe.imageUrls.first : null;

    await savedRef.set({
      'recipeId': recipe.id,
      'folder': folder,
      'imageUrl': imageUrl,
      'savedAt': FieldValue.serverTimestamp(),
    });

    final folderRef = _folderCol(uid).doc(folder);
    final folderSnap = await folderRef.get();

    if (!folderSnap.exists) {
      // New folder created implicitly by this save, auto cover
      await folderRef.set({
        'name': folder,
        'coverImageUrl': imageUrl,
        'coverIsCustom': false,
        'recipeCount': 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      final data = folderSnap.data() ?? {};
      final int prevCount = (data['recipeCount'] as int?) ?? 0;
      final bool coverIsCustom = (data['coverIsCustom'] as bool?) ?? false;
      String? coverImageUrl = data['coverImageUrl'] as String?;

      // If cover is auto and we have an image, use the *latest saved* image.
      if (!coverIsCustom && imageUrl != null) {
        coverImageUrl = imageUrl;
      }

      await folderRef.set(
        {
          'name': folder,
          'recipeCount': prevCount + 1,
          'coverImageUrl': coverImageUrl,
          'coverIsCustom': coverIsCustom,
        },
        SetOptions(merge: true),
      );
    }
  }

  /// Explicit remove (used from Saved page “bookmark” icon) or from toggle.
  ///
  /// After deleting the saved recipe, we recompute:
  ///   - recipeCount
  ///   - auto cover (latest remaining recipe's image)
  /// Custom covers are preserved.
  Future<void> removeSaved({
    required String uid,
    required String recipeId,
  }) async {
    final savedRef = _savedCol(uid).doc(recipeId);
    final snap = await savedRef.get();
    if (!snap.exists) return;

    final data = snap.data() ?? {};
    final folderName = (data['folder'] as String?) ?? 'General';

    await savedRef.delete();

    final folderRef = _folderCol(uid).doc(folderName);
    final folderSnap = await folderRef.get();

    if (!folderSnap.exists) {
      // No folder doc to update (older data) – nothing more to do.
      return;
    }

    final folderData = folderSnap.data() ?? {};
    final bool coverIsCustom = (folderData['coverIsCustom'] as bool?) ?? false;
    final String? customCover = folderData['coverImageUrl'] as String?;

    final meta = await _computeFolderMeta(uid, folderName);

    await folderRef.set(
      {
        'name': folderName,
        'recipeCount': meta.count,
        'coverImageUrl':
            coverIsCustom ? customCover : meta.coverImageUrl,
        'coverIsCustom': coverIsCustom,
      },
      SetOptions(merge: true),
    );
  }

  /// Create an empty folder (no recipes yet), optionally with a custom cover.
  Future<void> createFolder({
    required String uid,
    required String name,
    String? coverImageUrl,
  }) async {
    final folderRef = _folderCol(uid).doc(name);
    await folderRef.set(
      {
        'name': name,
        'coverImageUrl': coverImageUrl,
        'coverIsCustom': coverImageUrl != null,
        'recipeCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Update folder cover image (used when user uploads a custom cover).
  ///
  /// We treat this as a *custom* cover and do not auto-change it later.
  /// Also ensures the folder doc exists (including for "All").
  Future<void> updateFolderCover({
    required String uid,
    required String folderName,
    required String coverImageUrl,
  }) async {
    final folderRef = _folderCol(uid).doc(folderName);
    final snap = await folderRef.get();

    await folderRef.set(
      {
        'name': folderName,
        'coverImageUrl': coverImageUrl,
        'coverIsCustom': true,
        if (!snap.exists) 'recipeCount': 0,
        if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Delete a folder metadata doc.
  ///
  /// This removes the folder tile from the UI but does NOT delete
  /// any saved_recipes. Those recipes will still appear under "All".
  Future<void> deleteFolder({
    required String uid,
    required String folderName,
  }) async {
    await _folderCol(uid).doc(folderName).delete();
  }

  /// Rename a folder (e.g. "General" -> "Dinner").
  ///
  /// - Copies the folder metadata to a new doc with [newName]
  /// - Updates all saved_recipes in that folder to the new name
  /// - Deletes the old folder doc
  Future<void> renameFolder({
    required String uid,
    required String oldName,
    required String newName,
  }) async {
    if (oldName == newName) return;
    if (oldName == 'All') return; // don't rename All

    final folderCol = _folderCol(uid);
    final oldRef = folderCol.doc(oldName);
    final oldSnap = await oldRef.get();
    if (!oldSnap.exists) return;

    final data = oldSnap.data() ?? {};

    final newRef = folderCol.doc(newName);
    final batch = _db.batch();

    // Copy metadata to new doc (update the name field)
    final Map<String, dynamic> newData =
        Map<String, dynamic>.from(data);
    newData['name'] = newName;
    batch.set(newRef, newData);

    // Update all saved_recipes that point at old folder name
    final savedSnap = await _savedCol(uid)
        .where('folder', isEqualTo: oldName)
        .get();

    for (final doc in savedSnap.docs) {
      batch.update(doc.reference, {'folder': newName});
    }

    // Delete old folder doc
    batch.delete(oldRef);

    await batch.commit();
  }

  /// Stream of folder names (if you need them elsewhere).
  Stream<List<String>> folders(String uid) {
    return _folderCol(uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return (data['name'] as String?) ?? doc.id;
      }).toList();
    });
  }

  /// Stream of folder previews: folder name + cover image + recipe count.
  ///
  /// Includes any folder docs we have:
  ///  - real folders (Desserts, Lunch, etc.)
  ///  - plus a special "All" doc if we ever set a cover for All.
  Stream<List<FolderPreview>> folderPreviews(String uid) {
    return _folderCol(uid)
        // no orderBy here; we sort in memory so docs without 'createdAt'
        // (like a newly created "All" cover) still show up
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        return FolderPreview(
          name: (data['name'] as String?) ?? doc.id,
          imageUrl: data['coverImageUrl'] as String?,
          count: (data['recipeCount'] as int?) ?? 0,
        );
      }).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  /// Stream of full Recipe objects the user has saved.
  ///
  /// If `folder` is provided, we filter by folder on the client side.
  Stream<List<Recipe>> savedRecipes(String uid, {String? folder}) {
    final query = _savedCol(uid).orderBy('savedAt', descending: true);

    return query.snapshots().asyncMap((snapshot) async {
      final docs = folder == null
          ? snapshot.docs
          : snapshot.docs.where((d) {
              final data = d.data();
              final f = data['folder'] as String?;
              return f == folder;
            }).toList();

      if (docs.isEmpty) return <Recipe>[];

      final futures = docs.map((savedDoc) async {
        final recipeId = savedDoc.id;

        final recipeSnap = await _db
            .collection('recipes')
            .doc(recipeId)
            .get();

        if (!recipeSnap.exists) return null;

        return Recipe.fromFirestore(
          recipeSnap as DocumentSnapshot<Map<String, dynamic>>,
        );
      }).toList();

      final results = await Future.wait(futures);
      return results.whereType<Recipe>().toList();
    });
  }

  /// Internal helper: count recipes in a folder + find the latest image.
  Future<_FolderMeta> _computeFolderMeta(
    String uid,
    String folderName,
  ) async {
    final snap = await _savedCol(uid)
        .orderBy('savedAt', descending: true)
        .get();

    int count = 0;
    String? cover;

    for (final doc in snap.docs) {
      final data = doc.data();
      final f = (data['folder'] as String?) ?? 'General';
      if (f != folderName) continue;

      count++;

      final img = data['imageUrl'] as String?;
      if (cover == null && img != null) {
        // Because we ordered by savedAt desc, first hit is the latest.
        cover = img;
      }
    }

    return _FolderMeta(count: count, coverImageUrl: cover);
  }
}

/// Model used in UI for folder previews.
class FolderPreview {
  final String name;
  final String? imageUrl;
  final int count;

  FolderPreview({
    required this.name,
    this.imageUrl,
    required this.count,
  });
}

/// Internal metadata holder for recomputing folder info.
class _FolderMeta {
  final int count;
  final String? coverImageUrl;

  _FolderMeta({
    required this.count,
    required this.coverImageUrl,
  });
}

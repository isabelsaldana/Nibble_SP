import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recipe.dart';

class SavedService {
  final _db = FirebaseFirestore.instance;

  /// This is your "All recipes" collection.
  static const String generalFolder = 'General';

  /// Subcollection: users/{uid}/saved_recipes/{recipeId}
  CollectionReference<Map<String, dynamic>> _savedCol(String uid) {
    return _db.collection('users').doc(uid).collection('saved_recipes');
  }

  /// Subcollection: users/{uid}/folders/{folderName}
  CollectionReference<Map<String, dynamic>> _folderCol(String uid) {
    return _db.collection('users').doc(uid).collection('folders');
  }

  // =======================
  //  STREAMS / CHECKS
  // =======================

  Stream<bool> isSavedStream(String uid, String recipeId) {
    return _savedCol(uid).doc(recipeId).snapshots().map((snap) => snap.exists);
  }

  Future<bool> isSaved({
    required String uid,
    required String recipeId,
  }) async {
    final doc = await _savedCol(uid).doc(recipeId).get();
    return doc.exists;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> savedDocStream(
    String uid,
    String recipeId,
  ) {
    return _savedCol(uid).doc(recipeId).snapshots();
  }

  // =======================
  //  SAVE / UNSAVE (MULTI)
  // =======================

  /// Ensure a recipe is saved (at least to General).
  /// If [alsoAddFolder] is provided, it will also be added.
  Future<void> ensureSaved({
    required String uid,
    required Recipe recipe,
    String? alsoAddFolder,
  }) async {
    final savedRef = _savedCol(uid).doc(recipe.id);
    final snap = await savedRef.get();

    final imageUrl = recipe.imageUrls.isNotEmpty ? recipe.imageUrls.first : null;

    final Set<String> folders = {generalFolder};
    if (alsoAddFolder != null && alsoAddFolder.trim().isNotEmpty) {
      folders.add(alsoAddFolder.trim());
    }

    if (!snap.exists) {
      await savedRef.set({
        'recipeId': recipe.id,
        'imageUrl': imageUrl,
        'savedAt': FieldValue.serverTimestamp(),
        'folders': folders.toList(),
      });
    } else {
      // Backward compat: merge any legacy "folder" into folders
      final data = snap.data() ?? {};
      final legacyFolder = data['folder'] as String?;
      final existingFolders = _readFoldersFromSavedDoc(data);

      final merged = <String>{
        ...existingFolders,
        generalFolder,
        if (legacyFolder != null && legacyFolder.trim().isNotEmpty) legacyFolder.trim(),
        ...folders,
      };

      await savedRef.set(
        {'folders': merged.toList()},
        SetOptions(merge: true),
      );
    }

    await _ensureFolderDoc(uid, generalFolder);
    if (alsoAddFolder != null &&
        alsoAddFolder.trim().isNotEmpty &&
        alsoAddFolder.trim() != generalFolder) {
      await _ensureFolderDoc(uid, alsoAddFolder.trim());
    }

    await _recomputeAllFolderMeta(uid);
  }

  /// Toggle membership of a recipe in a folder.
  ///
  /// - If recipe isn't saved, this will save it (General + folder).
  /// - General cannot be removed.
  Future<void> toggleInFolder({
    required String uid,
    required Recipe recipe,
    required String folderName,
  }) async {
    final folder = folderName.trim();
    if (folder.isEmpty) return;

    // General is locked (always included)
    if (folder == generalFolder) {
      await ensureSaved(uid: uid, recipe: recipe);
      return;
    }

    final savedRef = _savedCol(uid).doc(recipe.id);
    final snap = await savedRef.get();

    if (!snap.exists) {
      await ensureSaved(uid: uid, recipe: recipe, alsoAddFolder: folder);
      return;
    }

    final data = snap.data() ?? {};
    final folders = _readFoldersFromSavedDoc(data).toSet();

    folders.add(generalFolder);

    if (folders.contains(folder)) {
      folders.remove(folder);
    } else {
      folders.add(folder);
      await _ensureFolderDoc(uid, folder);
    }

    await savedRef.set(
      {'folders': folders.toList()},
      SetOptions(merge: true),
    );

    await _recomputeAllFolderMeta(uid);
  }

  /// Remove saved completely (deletes the saved_recipes doc).
  Future<void> removeSaved({
    required String uid,
    required String recipeId,
  }) async {
    final ref = _savedCol(uid).doc(recipeId);
    final snap = await ref.get();
    if (!snap.exists) return;

    await ref.delete();
    await _recomputeAllFolderMeta(uid);
  }

  // =======================
  //  FOLDERS CRUD
  // =======================

  Future<void> createFolder({
    required String uid,
    required String name,
    String? coverImageUrl,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (trimmed == generalFolder) return;

    final folderRef = _folderCol(uid).doc(trimmed);
    await folderRef.set(
      {
        'name': trimmed,
        'coverImageUrl': coverImageUrl,
        'coverIsCustom': coverImageUrl != null,
        'recipeCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

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

  /// Delete folder metadata doc.
  /// - General cannot be deleted unless no saved recipes exist.
  /// - Deleting a folder ALSO removes that folder from all saved docs.
  Future<void> deleteFolder({
    required String uid,
    required String folderName,
  }) async {
    final folder = folderName.trim();
    if (folder.isEmpty) return;

    if (folder == generalFolder) {
      final meta = await _computeGeneralMeta(uid);
      if (meta.count > 0) {
        throw Exception("Can't delete General unless there are no saved recipes.");
      }
      await _folderCol(uid).doc(folder).delete();
      return;
    }

    // Remove folder from all saved docs that have it
    final savedSnap = await _savedCol(uid).get();
    final batch = _db.batch();

    for (final doc in savedSnap.docs) {
      final data = doc.data();
      final folders = _readFoldersFromSavedDoc(data).toSet();
      if (!folders.contains(folder)) continue;

      folders.remove(folder);
      folders.add(generalFolder);

      batch.set(
        doc.reference,
        {'folders': folders.toList()},
        SetOptions(merge: true),
      );
    }

    batch.delete(_folderCol(uid).doc(folder));
    await batch.commit();

    await _recomputeAllFolderMeta(uid);
  }

  /// Rename a folder:
  /// - Updates folder doc id and name
  /// - Updates membership in all saved docs (folders array)
  Future<void> renameFolder({
    required String uid,
    required String oldName,
    required String newName,
  }) async {
    final o = oldName.trim();
    final n = newName.trim();
    if (o.isEmpty || n.isEmpty) return;
    if (o == n) return;

    if (o == generalFolder) return;
    if (n == generalFolder) return;

    final oldRef = _folderCol(uid).doc(o);
    final oldSnap = await oldRef.get();
    if (!oldSnap.exists) return;

    final data = oldSnap.data() ?? {};
    final newRef = _folderCol(uid).doc(n);

    final batch = _db.batch();

    final newData = Map<String, dynamic>.from(data);
    newData['name'] = n;
    batch.set(newRef, newData);
    batch.delete(oldRef);

    // Update saved docs
    final savedSnap = await _savedCol(uid).get();
    for (final doc in savedSnap.docs) {
      final d = doc.data();
      final folders = _readFoldersFromSavedDoc(d).toSet();
      if (!folders.contains(o)) continue;

      folders.remove(o);
      folders.add(n);
      folders.add(generalFolder);

      batch.set(
        doc.reference,
        {'folders': folders.toList()},
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    await _recomputeAllFolderMeta(uid);
  }

  // =======================
  //  UI STREAMS
  // =======================

  /// Folder previews (General always present, first)
  Stream<List<FolderPreview>> folderPreviews(String uid) {
    return _folderCol(uid).snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        return FolderPreview(
          name: (data['name'] as String?) ?? doc.id,
          imageUrl: data['coverImageUrl'] as String?,
          count: (data['recipeCount'] as int?) ?? 0,
        );
      }).toList();

      final hasGeneral = list.any((f) => f.name == generalFolder);
      if (!hasGeneral) {
        list.insert(0, FolderPreview(name: generalFolder, imageUrl: null, count: 0));
      }

      list.sort((a, b) {
        if (a.name == generalFolder) return -1;
        if (b.name == generalFolder) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return list;
    });
  }

  /// Saved recipes stream.
  ///
  /// IMPORTANT: This avoids Firestore composite-index issues by:
  /// - Always querying ORDER BY savedAt
  /// - Filtering by folder on the client
  Stream<List<Recipe>> savedRecipes(String uid, {String? folder}) {
    final query = _savedCol(uid).orderBy('savedAt', descending: true);

    return query.snapshots().asyncMap((snapshot) async {
      final f = (folder == null || folder == generalFolder) ? null : folder.trim();

      final docs = f == null
          ? snapshot.docs
          : snapshot.docs.where((d) {
              final data = d.data();
              final folders = _readFoldersFromSavedDoc(data);
              return folders.contains(f);
            }).toList();

      if (docs.isEmpty) return <Recipe>[];

      final futures = docs.map((savedDoc) async {
        final recipeId = savedDoc.id;
        final recipeSnap = await _db.collection('recipes').doc(recipeId).get();
        if (!recipeSnap.exists) return null;
        return Recipe.fromFirestore(recipeSnap);
      }).toList();

      final results = await Future.wait(futures);
      return results.whereType<Recipe>().toList();
    });
  }

  // =======================
  //  INTERNAL HELPERS
  // =======================

  List<String> _readFoldersFromSavedDoc(Map<String, dynamic> data) {
    final raw = data['folders'];
    final out = <String>{generalFolder};

    if (raw is List) {
      for (final e in raw) {
        final s = e.toString().trim();
        if (s.isNotEmpty) out.add(s);
      }
    }

    // Backward compat: if legacy "folder" exists, include it too
    final legacy = data['folder'] as String?;
    if (legacy != null && legacy.trim().isNotEmpty) {
      out.add(legacy.trim());
    }

    return out.toList();
  }

  Future<void> _ensureFolderDoc(String uid, String folderName) async {
    final ref = _folderCol(uid).doc(folderName);
    final snap = await ref.get();
    if (snap.exists) return;

    await ref.set({
      'name': folderName,
      'coverImageUrl': null,
      'coverIsCustom': false,
      'recipeCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _recomputeAllFolderMeta(String uid) async {
    // Make sure General exists
    await _ensureFolderDoc(uid, generalFolder);

    final savedSnap = await _savedCol(uid).orderBy('savedAt', descending: true).get();
    final folderSnap = await _folderCol(uid).get();

    final folderDocs = {
      for (final d in folderSnap.docs) d.id: d.data(),
    };

    // counts + latest cover per folder (latest savedAt that belongs to that folder)
    final Map<String, int> counts = {};
    final Map<String, String?> covers = {};

    void bump(String folder, String? imageUrl) {
      counts[folder] = (counts[folder] ?? 0) + 1;
      covers.putIfAbsent(folder, () => (imageUrl != null && imageUrl.trim().isNotEmpty) ? imageUrl : null);
    }

    for (final doc in savedSnap.docs) {
      final data = doc.data();
      final img = data['imageUrl'] as String?;
      final folders = _readFoldersFromSavedDoc(data);

      for (final f in folders) {
        bump(f, img);
      }
    }

    final batch = _db.batch();

    // Update every existing folder doc (and General) with accurate count/cover (unless custom cover)
    final allFolderNames = <String>{...folderDocs.keys, generalFolder, ...counts.keys};

    for (final name in allFolderNames) {
      final ref = _folderCol(uid).doc(name);
      final existing = folderDocs[name] ?? {};
      final coverIsCustom = (existing['coverIsCustom'] as bool?) ?? false;
      final customCover = existing['coverImageUrl'] as String?;

      batch.set(
        ref,
        {
          'name': name,
          'recipeCount': counts[name] ?? 0,
          'coverIsCustom': coverIsCustom,
          'coverImageUrl': coverIsCustom ? customCover : covers[name],
          if (!folderDocs.containsKey(name)) 'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<_FolderMeta> _computeGeneralMeta(String uid) async {
    final snap = await _savedCol(uid).get();
    return _FolderMeta(count: snap.docs.length, coverImageUrl: null);
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

class _FolderMeta {
  final int count;
  final String? coverImageUrl;

  _FolderMeta({required this.count, required this.coverImageUrl});
}


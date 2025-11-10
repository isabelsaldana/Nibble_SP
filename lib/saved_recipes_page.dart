import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'models/recipe.dart';
import 'services/saved_service.dart';
import 'pages/view_recipe_page.dart';

enum _FolderMenuAction { rename, cover, delete }

class SavedRecipesPage extends StatefulWidget {
  const SavedRecipesPage({super.key});

  @override
  State<SavedRecipesPage> createState() => _SavedRecipesPageState();
}

class _SavedRecipesPageState extends State<SavedRecipesPage> {
  final _saved = SavedService();

  bool _showFolders = true;      // true = folder grid, false = recipe grid
  String? _selectedFolder;       // null = All

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return const Center(child: Text('Please sign in to see saved recipes.'));
    }

    final uid = me.uid;

    return Scaffold(
      body: SafeArea(
        child: _showFolders
            ? _buildFolderGrid(uid)
            : _buildFolderContents(uid),
      ),
    );
  }

  // =======================
  //  FOLDER GRID VIEW
  // =======================

  Widget _buildFolderGrid(String uid) {
    return StreamBuilder<List<FolderPreview>>(
      stream: _saved.folderPreviews(uid),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error loading folders: ${snap.error}'),
          );
        }

        if (snap.connectionState == ConnectionState.waiting &&
            (snap.data == null || snap.data!.isEmpty)) {
          return const Center(child: CircularProgressIndicator());
        }

        final allFolders = snap.data ?? [];

        // Separate special "All" doc (if present) from real folders
        FolderPreview? allPreview;
        final realFolders = <FolderPreview>[];
        for (final f in allFolders) {
          if (f.name == 'All') {
            allPreview = f;
          } else {
            realFolders.add(f);
          }
        }

        final totalCount =
            realFolders.fold<int>(0, (sum, f) => sum + f.count);

        // Grid items now:
        // index 0     => "All"
        // 1..n        => existing folders
        final itemCount = realFolders.length + 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Header with "Collections" + plus button ----
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Text(
                    'Collections',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'New collection',
                    onPressed: () => _createFolderDialog(uid),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 3 / 4,
                ),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  // "All" tile
                  if (index == 0) {
                    final imageUrl = allPreview?.imageUrl;

                    final subtitle = totalCount == 1
                        ? '1 recipe'
                        : '$totalCount recipes';

                    return _FolderGridTile(
                      label: 'All',
                      subtitle: subtitle,
                      imageUrl: imageUrl,
                      onTap: () {
                        setState(() {
                          _selectedFolder = null; // All
                          _showFolders = false;
                        });
                      },
                    );
                  }

                  // Real folder tiles
                  final folder = realFolders[index - 1];
                  final subtitle = folder.count == 1
                      ? '1 recipe'
                      : '${folder.count} recipes';

                  return _FolderGridTile(
                    label: folder.name,
                    subtitle: subtitle,
                    imageUrl: folder.imageUrl,
                    onTap: () {
                      setState(() {
                        _selectedFolder = folder.name;
                        _showFolders = false;
                      });
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // =======================
  //  FOLDER CONTENT (RECIPES)
  // =======================

  Widget _buildFolderContents(String uid) {
    final folderName = _selectedFolder ?? 'All';
    final isAll = folderName == 'All';

    return Column(
      children: [
        // Header row with back + title + menu
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _showFolders = true;
                  });
                },
              ),
              const SizedBox(width: 4),
              Text(
                folderName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              PopupMenuButton<_FolderMenuAction>(
                icon: const Icon(Icons.more_vert),
                onSelected: (action) {
                  switch (action) {
                    case _FolderMenuAction.rename:
                      _renameFolder(uid, folderName);
                      break;
                    case _FolderMenuAction.cover:
                      _changeFolderCover(uid, folderName);
                      break;
                    case _FolderMenuAction.delete:
                      _confirmDeleteFolder(uid, folderName);
                      break;
                  }
                },
                itemBuilder: (ctx) {
                  final items =
                      <PopupMenuEntry<_FolderMenuAction>>[];

                  if (!isAll) {
                    items.add(
                      const PopupMenuItem(
                        value: _FolderMenuAction.rename,
                        child: Text('Rename collection'),
                      ),
                    );
                  }

                  items.add(
                    const PopupMenuItem(
                      value: _FolderMenuAction.cover,
                      child: Text('Change cover photo'),
                    ),
                  );

                  if (!isAll) {
                    items.add(
                      const PopupMenuItem(
                        value: _FolderMenuAction.delete,
                        child: Text('Delete collection'),
                      ),
                    );
                  }

                  return items;
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<List<Recipe>>(
            stream: _saved.savedRecipes(uid, folder: _selectedFolder),
            builder: (context, snap) {
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Error loading saved recipes: ${snap.error}',
                  ),
                );
              }

              if (snap.connectionState == ConnectionState.waiting &&
                  (snap.data == null || snap.data!.isEmpty)) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final items = snap.data ?? [];

              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 56,
                        color: Colors.brown.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedFolder == null
                            ? 'No saved recipes yet'
                            : 'No recipes in "${_selectedFolder!}" yet',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap the bookmark icon on any recipe to save it here.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 3 / 4,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final r = items[index];
                  final imageUrl =
                      r.imageUrls.isNotEmpty ? r.imageUrls.first : null;

                  return _SavedRecipeTile(
                    recipe: r,
                    imageUrl: imageUrl,
                    uid: uid,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // =======================
  //  HELPERS
  // =======================

  /// Dialog: create an empty folder (no recipes yet).
  Future<void> _createFolderDialog(String uid) async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('New folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. Desserts, Weeknight dinners',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final raw = controller.text.trim();
                if (raw.isEmpty) return;
                Navigator.of(dialogCtx).pop(raw);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (name == null || name.trim().isEmpty) return;

    await _saved.createFolder(uid: uid, name: name.trim());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Folder "$name" created'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  /// Confirm and delete a folder metadata doc.
  ///
  /// This does NOT delete saved recipes – they will still appear under "All".
  Future<void> _confirmDeleteFolder(String uid, String folderName) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Delete collection?'),
              content: Text(
                'This will remove the collection "$folderName". '
                'Saved recipes will stay in "All".',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDelete) return;

    await _saved.deleteFolder(uid: uid, folderName: folderName);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Collection "$folderName" deleted'),
        duration: const Duration(milliseconds: 900),
      ),
    );

    // If we were viewing this folder, go back to grid
    if (_selectedFolder == folderName) {
      setState(() {
        _selectedFolder = null;
        _showFolders = true;
      });
    }
  }

  /// Rename folder (edit collection name).
  Future<void> _renameFolder(String uid, String currentName) async {
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Rename collection'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Collection name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final raw = controller.text.trim();
                if (raw.isEmpty) return;
                Navigator.of(dialogCtx).pop(raw);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName == null) return;
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == currentName) return;

    await _saved.renameFolder(
      uid: uid,
      oldName: currentName,
      newName: trimmed,
    );

    if (!mounted) return;
    setState(() {
      _selectedFolder = trimmed;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Renamed to "$trimmed"'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  /// Allows user to upload/change a folder cover photo (including "All").
  Future<void> _changeFolderCover(String uid, String folderName) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final storageRef = FirebaseStorage.instance
        .ref()
        .child(
            'users/$uid/folder_covers/${DateTime.now().millisecondsSinceEpoch}_${picked.name}');

    await storageRef.putData(bytes);
    final url = await storageRef.getDownloadURL();

    await _saved.updateFolderCover(
      uid: uid,
      folderName: folderName,
      coverImageUrl: url,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          folderName == 'All'
              ? 'Updated cover for All'
              : 'Updated cover for "$folderName"',
        ),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }
}

// =======================
//  UI WIDGETS
// =======================

/// Big folder tile that looks like the recipe cards (2-column grid).
class _FolderGridTile extends StatelessWidget {
  const _FolderGridTile({
    required this.label,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              Image.network(
                imageUrl!,
                fit: BoxFit.cover,
              )
            else
              Container(
                color: Colors.brown.shade100,
                alignment: Alignment.center,
                child: const Icon(Icons.restaurant, size: 32),
              ),

            // Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Label + subtitle
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedRecipeTile extends StatelessWidget {
  const _SavedRecipeTile({
    required this.recipe,
    required this.imageUrl,
    required this.uid,
  });

  final Recipe recipe;
  final String? imageUrl;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final svc = SavedService();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewRecipePage(recipe: recipe),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            imageUrl == null
                ? Container(
                    color: Colors.brown.shade100,
                    alignment: Alignment.center,
                    child: const Icon(Icons.restaurant, size: 32),
                  )
                : Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                  ),
            // Gradient overlay bottom for text + icon
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Title + unsave icon
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      recipe.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      await svc.removeSaved(
                        uid: uid,
                        recipeId: recipe.id,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Removed from saved'),
                            duration: Duration(milliseconds: 800),
                          ),
                        );
                      }
                    },
                    child: const Icon(
                      Icons.bookmark,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

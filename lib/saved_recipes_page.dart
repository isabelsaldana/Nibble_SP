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

  bool _showFolders = true; // true = folder grid, false = recipe grid
  String _selectedFolder = SavedService.generalFolder; // General = "All recipes"

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return const Center(child: Text('Please sign in to see saved recipes.'));
    }

    final uid = me.uid;

    return Scaffold(
      body: SafeArea(
        child: _showFolders ? _buildFolderGrid(uid) : _buildFolderContents(uid),
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

        final folders = snap.data ?? [];

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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 3 / 4,
                ),
                itemCount: folders.length,
                itemBuilder: (context, index) {
                  final folder = folders[index];
                  final subtitle =
                      folder.count == 1 ? '1 recipe' : '${folder.count} recipes';

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
    final folderName = _selectedFolder;
    final isGeneral = folderName == SavedService.generalFolder;

    return StreamBuilder<List<Recipe>>(
      stream: _saved.savedRecipes(uid, folder: folderName),
      builder: (context, snap) {
        final items = snap.data ?? [];
        final canDeleteGeneral = isGeneral && items.isEmpty;

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
                      setState(() => _showFolders = true);
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
                    onSelected: (action) async {
                      switch (action) {
                        case _FolderMenuAction.rename:
                          await _renameFolder(uid, folderName);
                          break;
                        case _FolderMenuAction.cover:
                          await _changeFolderCover(uid, folderName);
                          break;
                        case _FolderMenuAction.delete:
                          await _confirmDeleteFolder(uid, folderName);
                          break;
                      }
                    },
                    itemBuilder: (ctx) {
                      final itemsMenu = <PopupMenuEntry<_FolderMenuAction>>[];

                      if (!isGeneral) {
                        itemsMenu.add(
                          const PopupMenuItem(
                            value: _FolderMenuAction.rename,
                            child: Text('Rename collection'),
                          ),
                        );
                      }

                      itemsMenu.add(
                        const PopupMenuItem(
                          value: _FolderMenuAction.cover,
                          child: Text('Change cover photo'),
                        ),
                      );

                      if (!isGeneral || canDeleteGeneral) {
                        itemsMenu.add(
                          const PopupMenuItem(
                            value: _FolderMenuAction.delete,
                            child: Text('Delete collection'),
                          ),
                        );
                      }

                      return itemsMenu;
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: Builder(
                builder: (_) {
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error loading saved recipes: ${snap.error}',
                      ),
                    );
                  }

                  if (snap.connectionState == ConnectionState.waiting &&
                      items.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

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
                            isGeneral
                                ? 'No saved recipes yet'
                                : 'No recipes in "$folderName" yet',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap the bookmark icon on any recipe to save it.',
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
                        currentFolder: folderName, // ✅ IMPORTANT
                      );
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
  //  HELPERS
  // =======================

  Future<void> _createFolderDialog(String uid) async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('New collection'),
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
        content: Text('Collection "$name" created'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _confirmDeleteFolder(String uid, String folderName) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Delete collection?'),
              content: Text(
                folderName == SavedService.generalFolder
                    ? 'This will delete "General". You can only do this when it is empty.'
                    : 'This will remove the collection "$folderName". Saved recipes will stay saved.',
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

    try {
      await _saved.deleteFolder(uid: uid, folderName: folderName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          duration: const Duration(milliseconds: 1400),
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Collection "$folderName" deleted'),
        duration: const Duration(milliseconds: 900),
      ),
    );

    if (_selectedFolder == folderName) {
      setState(() {
        _selectedFolder = SavedService.generalFolder;
        _showFolders = true;
      });
    }
  }

  Future<void> _renameFolder(String uid, String currentName) async {
    if (currentName == SavedService.generalFolder) return;

    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Rename collection'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Collection name'),
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
    setState(() => _selectedFolder = trimmed);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Renamed to "$trimmed"'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _changeFolderCover(String uid, String folderName) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final storageRef = FirebaseStorage.instance.ref().child(
          'users/$uid/folder_covers/${DateTime.now().millisecondsSinceEpoch}_${picked.name}',
        );

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
          folderName == SavedService.generalFolder
              ? 'Updated cover for General'
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
              Image.network(imageUrl!, fit: BoxFit.cover)
            else
              Container(
                color: Colors.brown.shade100,
                alignment: Alignment.center,
                child: const Icon(Icons.restaurant, size: 32),
              ),
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
    required this.currentFolder, // ✅ add
  });

  final Recipe recipe;
  final String? imageUrl;
  final String uid;
  final String currentFolder; // ✅ add

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
            imageUrl == null
                ? Container(
                    color: Colors.brown.shade100,
                    alignment: Alignment.center,
                    child: const Icon(Icons.restaurant, size: 32),
                  )
                : Image.network(imageUrl!, fit: BoxFit.cover),
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
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Row(
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

                  // ✅ IMPORTANT: remove from folder OR remove everywhere w/ confirm
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      // Stop the tile tap from firing
                      // (GestureDetector already prevents InkWell onTap most of the time)
                      // but this makes it feel consistent.
                      if (currentFolder != SavedService.generalFolder) {
                        await svc.toggleInFolder(
                          uid: uid,
                          recipe: recipe,
                          folderName: currentFolder,
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Removed from "$currentFolder"'),
                              duration: const Duration(milliseconds: 800),
                            ),
                          );
                        }
                        return;
                      }

                      final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Remove from saved?"),
                              content: const Text(
                                'This will remove this recipe from General and from ALL of your collections.\n\nAre you sure?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text("Cancel"),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text("Remove"),
                                ),
                              ],
                            ),
                          ) ??
                          false;

                      if (!ok) return;

                      await svc.removeSaved(uid: uid, recipeId: recipe.id);

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

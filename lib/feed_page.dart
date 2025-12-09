// lib/feed_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'models/recipe.dart';
import 'pages/view_recipe_page.dart';
import 'services/saved_service.dart';

/// Helper: "2h ago", "3d ago", etc.
String _timeAgo(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final weeks = diff.inDays ~/ 7;
  return '${weeks}w ago';
}

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('recipes')
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error loading feed: ${snap.error}'),
              ),
            );
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No public recipes yet.'),
              ),
            );
          }

          final recipes = docs.map((d) => Recipe.fromFirestore(d)).toList();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: recipes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final r = recipes[index];
              return _FeedRecipeCard(recipe: r);
            },
          );
        },
      ),
    );
  }
}

class _FeedRecipeCard extends StatefulWidget {
  const _FeedRecipeCard({required this.recipe});

  final Recipe recipe;

  @override
  State<_FeedRecipeCard> createState() => _FeedRecipeCardState();
}

class _FeedRecipeCardState extends State<_FeedRecipeCard> {
  final _savedSvc = SavedService();
  bool _isSaved = false;
  bool _loading = false;

  // Likes
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    _loadInitialSavedState();
    _loadLike();
  }

  Future<void> _loadInitialSavedState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final saved = await _savedSvc.isSaved(
      uid: user.uid,
      recipeId: widget.recipe.id,
    );

    if (!mounted) return;
    setState(() => _isSaved = saved);
  }

  Future<void> _loadLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final likeDoc = await FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipe.id)
        .collection('likes')
        .doc(user.uid)
        .get();

    if (!mounted) return;
    setState(() => _liked = likeDoc.exists);
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final ref = FirebaseFirestore.instance
          .collection('recipes')
          .doc(widget.recipe.id)
          .collection('likes')
          .doc(user.uid);

      if (_liked) {
        await ref.delete();
      } else {
        await ref.set({'likedAt': FieldValue.serverTimestamp()});
      }

      if (!mounted) return;
      setState(() => _liked = !_liked);
    } catch (e) {
      debugPrint("Like error: $e");
    }
  }

  Future<void> _onSavePressed() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to save recipes'),
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }

    if (_isSaved) {
      setState(() => _loading = true);
      try {
        await _savedSvc.removeSaved(
          uid: user.uid,
          recipeId: widget.recipe.id,
        );
        if (!mounted) return;
        setState(() => _isSaved = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from saved'),
            duration: Duration(milliseconds: 900),
          ),
        );
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }

    await _showSaveBottomSheet(user.uid);
  }

  // ⭐ FIXED — Correct structure & scroll to prevent overflow
  Future<void> _showSaveBottomSheet(String uid) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Save to',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  SizedBox(
                    height: 260,
                    child: StreamBuilder<List<FolderPreview>>(
                      stream: _savedSvc.folderPreviews(uid),
                      builder: (ctx, snap) {
                        if (snap.hasError) {
                          return Center(
                            child: Text('Error loading folders: ${snap.error}'),
                          );
                        }
                        if (!snap.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final folders = (snap.data ?? [])
                            .where((f) => f.name != "All")
                            .toList();

                        if (folders.isEmpty) {
                          return const Center(
                            child: Text(
                              'No folders yet.\nTap "New folder" below to create one.',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: folders.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final folder = folders[i];
                            return ListTile(
                              leading: folder.imageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        folder.imageUrl!,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.brown.shade100,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.restaurant),
                                    ),
                              title: Text(folder.name),
                              subtitle: Text(
                                folder.count == 1
                                    ? '1 recipe'
                                    : '${folder.count} recipes',
                              ),
                              trailing: const Icon(Icons.add),
                              onTap: () async {
                                await _savedSvc.toggleSaved(
                                  uid: uid,
                                  recipe: widget.recipe,
                                  folder: folder.name,
                                );

                                if (!mounted) return;
                                setState(() => _isSaved = true);
                                Navigator.of(sheetCtx).pop();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Saved to "${folder.name}"')),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const Divider(),

                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('New folder'),
                    onTap: () async {
                      final name =
                          await _createFolderDialogFromFeed(sheetCtx, uid);
                      if (name != null && name.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Folder "$name" created')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _createFolderDialogFromFeed(
      BuildContext context, String uid) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('New Folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Folder name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  await _savedSvc.createFolder(uid: uid, name: name);
                  Navigator.pop(ctx, name);
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final imageUrl = r.imageUrls.isNotEmpty ? r.imageUrls.first : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ViewRecipePage(recipe: r),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Hero(
              tag: 'recipe_${r.id}',
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: imageUrl == null
                    ? Container(
                        color: Colors.brown.shade100,
                        alignment: Alignment.center,
                        child: const Icon(Icons.restaurant, size: 40),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(0),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),

                  if (r.description != null &&
                      r.description!.trim().isNotEmpty) ...[
                    Text(
                      r.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                  ],

                  Row(
                    children: [
                      Text(
                        'Public',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.brown.shade400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (r.createdAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• ${_timeAgo(r.createdAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.brown.shade300,
                          ),
                        ),
                      ],
                      const Spacer(),

                      // Like button
                      IconButton(
                        icon: Icon(
                          _liked
                              ? Icons.favorite
                              : Icons.favorite_border_outlined,
                          color: _liked ? Colors.red : null,
                        ),
                        onPressed: _toggleLike,
                      ),

                      // Save button
                      IconButton(
                        tooltip: _isSaved ? 'Unsave' : 'Save',
                        onPressed: _loading ? null : _onSavePressed,
                        icon: Icon(
                          _isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_border_outlined,
                        ),
                      ),
                    ],
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

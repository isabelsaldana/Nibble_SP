// lib/feed_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'models/recipe.dart';
import 'pages/view_recipe_page.dart';
import 'pages/comments_page.dart';
import 'public_profile_page.dart';
import 'services/saved_service.dart';

// ✅ NEW
import 'moderation/likes_sheet.dart';

String _timeAgo(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);

  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${diff.inDays ~/ 7}w ago';
}

// ✅ IG-ish count formatting (34.8K, 1.2M)
String _compactCount(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) return '${(n / 1000).toStringAsFixed(n < 10000 ? 1 : 0)}K';
  return '${(n / 1000000).toStringAsFixed(n < 10000000 ? 1 : 0)}M';
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
      // ✅ ADD THIS APP BAR (centered logo)
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: false, // keeps it truly centered
        title: Image.asset(
          'assets/branding/nibble_wordmark.png', // ✅ your logo asset path
          height: 28,
          fit: BoxFit.contain,
        ),
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No public recipes yet."));
          }

          final recipes = docs.map((d) => Recipe.fromFirestore(d)).toList();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: recipes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _FeedRecipeCard(recipe: recipes[i]),
          );
        },
      ),
    );
  }
}

class _FeedRecipeCard extends StatefulWidget {
  final Recipe recipe;
  const _FeedRecipeCard({required this.recipe});

  @override
  State<_FeedRecipeCard> createState() => _FeedRecipeCardState();
}

class _FeedRecipeCardState extends State<_FeedRecipeCard> {
  final _savedSvc = SavedService();
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    _loadLike();
  }

  Future<void> _loadLike() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final likeDoc = await FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipe.id)
        .collection('likes')
        .doc(uid)
        .get();

    if (!mounted) return;
    setState(() => _liked = likeDoc.exists);
  }

  Future<void> _toggleLike() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance
        .collection('recipes')
        .doc(widget.recipe.id)
        .collection('likes')
        .doc(uid);

    if (_liked) {
      await ref.delete();
    } else {
      await ref.set({'likedAt': FieldValue.serverTimestamp()});
    }

    if (!mounted) return;
    setState(() => _liked = !_liked);
  }

  // ✅ IG-style Comments Sheet
  Future<void> _openComments() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: CommentsPage(
          recipeId: widget.recipe.id,
          recipeTitle: widget.recipe.title,
        ),
      ),
    );
  }

  Future<void> _onSavePressed() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sign in to save recipes")),
      );
      return;
    }

    await _savedSvc.ensureSaved(uid: uid, recipe: widget.recipe);
    if (!mounted) return;

    await _showSaveCollectionsSheet(uid: uid, recipe: widget.recipe);
  }

  Future<void> _showSaveCollectionsSheet({
    required String uid,
    required Recipe recipe,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _savedSvc.savedDocStream(uid, recipe.id),
              builder: (context, savedSnap) {
                final savedExists = savedSnap.data?.exists == true;
                final data = savedSnap.data?.data() ?? {};

                final foldersRaw = data['folders'];
                final folders = (foldersRaw is List)
                    ? foldersRaw.map((e) => e.toString()).toList()
                    : <String>[SavedService.generalFolder];

                bool inFolder(String name) => folders.contains(name);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Save to…",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    ListTile(
                      leading: const Icon(Icons.bookmark),
                      title: const Text("General (All recipes)"),
                      subtitle: const Text("Always included when you save"),
                      trailing: const Icon(Icons.lock, size: 18),
                      onTap: () async {
                        await _savedSvc.ensureSaved(uid: uid, recipe: recipe);
                      },
                    ),

                    const Divider(),

                    StreamBuilder<List<FolderPreview>>(
                      stream: _savedSvc.folderPreviews(uid),
                      builder: (context, folderSnap) {
                        final all = folderSnap.data ?? [];
                        final foldersOnly = all
                            .where((f) => f.name != SavedService.generalFolder)
                            .toList();

                        return Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              for (final f in foldersOnly)
                                ListTile(
                                  leading: const Icon(Icons.folder_outlined),
                                  title: Text(f.name),
                                  trailing: inFolder(f.name)
                                      ? const Icon(Icons.check, size: 18)
                                      : null,
                                  onTap: () async {
                                    await _savedSvc.toggleInFolder(
                                      uid: uid,
                                      recipe: recipe,
                                      folderName: f.name,
                                    );
                                  },
                                ),

                              const Divider(),

                              ListTile(
                                leading: const Icon(Icons.add),
                                title: const Text("New collection"),
                                onTap: () async {
                                  final name = await _askForFolderName(sheetCtx);
                                  if (name == null || name.trim().isEmpty) return;

                                  final trimmed = name.trim();
                                  await _savedSvc.createFolder(uid: uid, name: trimmed);

                                  await _savedSvc.toggleInFolder(
                                    uid: uid,
                                    recipe: recipe,
                                    folderName: trimmed,
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: savedExists
                              ? () async {
                                  await _savedSvc.removeSaved(
                                    uid: uid,
                                    recipeId: recipe.id,
                                  );
                                  if (Navigator.of(sheetCtx).canPop()) {
                                    Navigator.of(sheetCtx).pop();
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text("Remove"),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            if (Navigator.of(sheetCtx).canPop()) {
                              Navigator.of(sheetCtx).pop();
                            }
                          },
                          child: const Text("Done"),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<String?> _askForFolderName(BuildContext ctx) async {
    final controller = TextEditingController();

    final res = await showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text("New collection"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "e.g., Dinner ideas"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text("Create"),
          ),
        ],
      ),
    );

    return res;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final imageUrl = r.imageUrls.isNotEmpty ? r.imageUrls.first : null;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ViewRecipePage(recipe: r)),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'recipe_${r.id}',
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: imageUrl == null
                    ? Container(
                        color: Colors.brown.shade100,
                        child: const Icon(Icons.restaurant, size: 40),
                      )
                    : Image.network(imageUrl, fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance
                        .collection("users")
                        .doc(r.authorId)
                        .get(),
                    builder: (_, snap) {
                      final u = snap.data?.data();

                      final photo = (u?["photo"] ?? u?["photoUrl"] ?? u?["photoURL"])
                          ?.toString()
                          .trim();
                      final hasPhoto = photo != null && photo.isNotEmpty;

                      final displayName =
                          (u?["displayName"] ?? u?["username"] ?? "User").toString();
                      final username = (u?["username"] ?? "").toString();

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PublicProfilePage(uid: r.authorId),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: hasPhoto ? NetworkImage(photo!) : null,
                              child: !hasPhoto ? const Icon(Icons.person, size: 18) : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              displayName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            if (username.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text("@$username",
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    r.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  if (r.description != null && r.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      r.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Text(
                        "Public • ${_timeAgo(r.createdAt)}",
                        style: TextStyle(fontSize: 12, color: Colors.brown.shade400),
                      ),
                      const Spacer(),

                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('recipes')
                            .doc(r.id)
                            .collection('comments')
                            .snapshots(),
                        builder: (context, snap) {
                          final count = snap.data?.docs.length ?? 0;
                          return Row(
                            children: [
                              InkWell(
                                onTap: _openComments,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                                  child: Text(_compactCount(count),
                                      style: const TextStyle(fontSize: 13)),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Comments',
                                icon: const Icon(Icons.chat_bubble_outline),
                                onPressed: _openComments,
                              ),
                            ],
                          );
                        },
                      ),

                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('recipes')
                            .doc(r.id)
                            .collection('likes')
                            .snapshots(),
                        builder: (context, snap) {
                          final count = snap.data?.docs.length ?? 0;
                          return InkWell(
                            onTap: () => LikesSheet.open(context, recipeId: r.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                              child: Text(_compactCount(count),
                                  style: const TextStyle(fontSize: 13)),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          _liked ? Icons.favorite : Icons.favorite_border,
                          color: _liked ? Colors.red : null,
                        ),
                        onPressed: _toggleLike,
                      ),

                      if (uid != null)
                        StreamBuilder<bool>(
                          stream: _savedSvc.isSavedStream(uid, r.id),
                          builder: (context, snap) {
                            final isSaved = snap.data ?? false;
                            return IconButton(
                              icon: Icon(isSaved
                                  ? Icons.bookmark
                                  : Icons.bookmark_border_outlined),
                              onPressed: _onSavePressed,
                            );
                          },
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.bookmark_border_outlined),
                          onPressed: _onSavePressed,
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

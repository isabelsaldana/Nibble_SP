// lib/pages/view_recipe_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../moderation/likes_sheet.dart';
import 'comments_page.dart';
import '../models/recipe.dart';
import '../services/saved_service.dart';
import '../public_profile_page.dart';
import '../home_page.dart';

// ✅ new
import '../moderation/report_ui.dart';
import '../moderation/report_service.dart';

class ViewRecipePage extends StatefulWidget {
  const ViewRecipePage({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<ViewRecipePage> createState() => _ViewRecipePageState();
}

class _ViewRecipePageState extends State<ViewRecipePage> {
  late final PageController _pageController;
  int _currentPage = 0;

  final _savedSvc = SavedService();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ✅ IG-style Comments Sheet (instead of pushing full page)
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

  String _difficultyLabel(String? diff) {
    switch (diff) {
      case 'easy':
        return 'Easy';
      case 'medium':
        return 'Medium';
      case 'hard':
        return 'Hard';
      default:
        return '—';
    }
  }

  Future<void> _showFullScreenImage(String imageUrl) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (ctx) {
        return GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: Hero(
                tag: 'recipe_${widget.recipe.id}_$_currentPage',
                child: InteractiveViewer(
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          size: 40,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onBookmarkPressed({
    required String uid,
    required Recipe recipe,
    required bool isSaved,
  }) async {
    if (!isSaved) {
      await _savedSvc.ensureSaved(uid: uid, recipe: recipe);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to General'),
          duration: Duration(milliseconds: 800),
        ),
      );
    }

    await _showSaveCollectionsSheet(uid: uid, recipe: recipe);
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

                if (!folders.contains(SavedService.generalFolder)) {
                  folders.add(SavedService.generalFolder);
                }

                bool inFolder(String folderName) => folders.contains(folderName);

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
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Removed from saved'),
                                      duration: Duration(milliseconds: 800),
                                    ),
                                  );
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
    final recipe = widget.recipe;
    final cs = Theme.of(context).colorScheme;

    final uid = FirebaseAuth.instance.currentUser?.uid;

    final images = recipe.imageUrls;
    final hasImages = images.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (uid != null)
            StreamBuilder<bool>(
              stream: _savedSvc.isSavedStream(uid, recipe.id),
              builder: (context, snap) {
                final isSaved = snap.data ?? false;
                return IconButton(
                  tooltip: isSaved ? 'Manage saved' : 'Save recipe',
                  icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                  onPressed: () async {
                    await _onBookmarkPressed(
                      uid: uid,
                      recipe: recipe,
                      isSaved: isSaved,
                    );
                  },
                );
              },
            ),

          PopupMenuButton<String>(
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'report', child: Text('Report recipe')),
            ],
            onSelected: (v) async {
              if (v == 'report') {
                await ReportUI.openReportSheet(
                  context,
                  title: 'Report recipe',
                  target: ReportTarget.recipe(
                    recipeId: recipe.id,
                    authorId: recipe.authorId,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasImages)
              Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      final currentUrl = images[_currentPage];
                      _showFullScreenImage(currentUrl);
                    },
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: images.length,
                          onPageChanged: (i) => setState(() => _currentPage = i),
                          itemBuilder: (context, index) {
                            final url = images[index];
                            return Hero(
                              tag: 'recipe_${recipe.id}_$index',
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.brown.shade100,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.broken_image_outlined, size: 32),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < images.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _currentPage ? 12 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _currentPage ? cs.primary : cs.primary.withOpacity(.25),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${images.length} photos · swipe to view',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.brown.shade400),
                  ),
                  const SizedBox(height: 16),
                ],
              )
            else
              const SizedBox(height: 12),

            // ✅ Likes + Comments row (IG-style taps)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('recipes')
                        .doc(recipe.id)
                        .collection('likes')
                        .snapshots(),
                    builder: (context, snap) {
                      final likeCount = snap.data?.docs.length ?? 0;
                      return InkWell(
                        onTap: () => LikesSheet.open(context, recipeId: recipe.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            likeCount == 1 ? '1 like' : '$likeCount likes',
                            style: TextStyle(
                              color: Colors.brown.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 14),

                  IconButton(
                    tooltip: 'Comments',
                    onPressed: _openComments,
                    icon: const Icon(Icons.chat_bubble_outline),
                  ),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('recipes')
                        .doc(recipe.id)
                        .collection('comments')
                        .snapshots(),
                    builder: (context, snap) {
                      final count = snap.data?.docs.length ?? 0;
                      return InkWell(
                        onTap: _openComments,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            count == 1 ? '1 comment' : '$count comments',
                            style: TextStyle(color: Colors.brown.shade600),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // (rest of your file stays the same)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),

                  FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance.collection("users").doc(recipe.authorId).get(),
                    builder: (context, snap) {
                      final user = snap.data?.data();
                      final photo = (user?["photo"] ?? user?["photoUrl"] ?? user?["photoURL"])
                          ?.toString()
                          .trim();
                      final hasPhoto = photo != null && photo.isNotEmpty;
                      final displayName =
                          (user?["displayName"] ?? user?["username"] ?? "Unknown").toString();
                      final username = (user?["username"] ?? "user").toString();

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => PublicProfilePage(uid: recipe.authorId)),
                          );
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundImage: hasPhoto ? NetworkImage(photo!) : null,
                              child: !hasPhoto ? const Icon(Icons.person, size: 18) : null,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                Text(
                                  "@$username",
                                  style: TextStyle(color: Colors.brown.shade500, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Icon(
                        recipe.isPublic ? Icons.public : Icons.lock_outline,
                        size: 16,
                        color: recipe.isPublic ? cs.primary : Colors.brown.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        recipe.isPublic ? 'Public recipe' : 'Private recipe',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.brown.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (recipe.tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      children: recipe.tags.map((tag) {
                        return InkWell(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HomePage(initialTab: 1, initialQuery: "#$tag"),
                              ),
                            );
                          },
                          child: Chip(label: Text("#$tag")),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          _MetaItem(
                            icon: Icons.timer_outlined,
                            label: 'Prep',
                            value: recipe.prepMinutes != null ? '${recipe.prepMinutes} min' : '—',
                          ),
                          _MetaItem(
                            icon: Icons.schedule_outlined,
                            label: 'Cook',
                            value: recipe.cookMinutes != null ? '${recipe.cookMinutes} min' : '—',
                          ),
                          _MetaItem(
                            icon: Icons.restaurant_outlined,
                            label: 'Serves',
                            value: recipe.servings?.toString() ?? '—',
                          ),
                          _MetaItem(
                            icon: Icons.leaderboard_outlined,
                            label: 'Difficulty',
                            value: _difficultyLabel(recipe.difficulty),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (recipe.description != null && recipe.description!.trim().isNotEmpty) ...[
                    Text(recipe.description!.trim(),
                        style: const TextStyle(fontSize: 14.5, height: 1.5)),
                    const SizedBox(height: 20),
                  ],

                  Text(
                    'Ingredients',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.brown.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final ing in recipe.ingredients)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("• "),
                                  Expanded(child: Text(ing)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Steps',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.brown.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < recipe.steps.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${i + 1}. ',
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Expanded(
                                    child: Text(recipe.steps[i],
                                        style: const TextStyle(height: 1.5)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
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

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: cs.primary),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, color: Colors.brown.shade500)),
            ],
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

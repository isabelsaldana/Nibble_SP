// lib/feed_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'models/recipe.dart';
import 'pages/view_recipe_page.dart';
import 'public_profile_page.dart';
import 'services/saved_service.dart';

String _timeAgo(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);

  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${diff.inDays ~/ 7}w ago';
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
      body: StreamBuilder(
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
  bool _isSaved = false;
  bool _liked = false;
  bool _loading = false;

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

  Future<void> _onSavePressed() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sign in to save recipes")),
      );
      return;
    }

    if (_isSaved) {
      setState(() => _loading = true);
      await _savedSvc.removeSaved(uid: uid, recipeId: widget.recipe.id);
      if (!mounted) return;
      setState(() => _isSaved = false);
      setState(() => _loading = false);
      return;
    }

    await _showSaveBottomSheet(uid);
  }

  Future<void> _showSaveBottomSheet(String uid) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text("Folder UI unchanged for this example"),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final imageUrl = r.imageUrls.isNotEmpty ? r.imageUrls.first : null;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewRecipePage(recipe: r),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------ IMAGE ------------------
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

            // ------------------ CONTENT ------------------
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ------------------ AUTHOR ROW ------------------
                  FutureBuilder(
                    future: FirebaseFirestore.instance
                        .collection("users")
                        .doc(r.authorId)
                        .get(),
                    builder: (_, snap) {
                      final u = snap.data?.data();

                      final photo = u?["photo"];
                      final displayName = u?["displayName"] ?? "User";
                      final username = u?["username"] ?? "";

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PublicProfilePage(uid: widget.recipe.authorId),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage:
                                  (photo != null && photo.toString().isNotEmpty)
                                      ? NetworkImage(photo)
                                      : null,
                              child: photo == null
                                  ? const Icon(Icons.person, size: 18)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "@$username",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // ------------------ TITLE ------------------
                  Text(
                    r.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  if (r.description != null &&
                      r.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      r.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // ------------------ FOOTER ROW ------------------
                  Row(
                    children: [
                      Text(
                        "Public • ${_timeAgo(r.createdAt)}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.brown.shade400,
                        ),
                      ),
                      const Spacer(),
                      StreamBuilder(
  stream: FirebaseFirestore.instance
      .collection('recipes')
      .doc(r.id)
      .collection('likes')
      .snapshots(),
  builder: (context, snap) {
    final count = snap.data?.docs.length ?? 0;
    return Text(
      "$count",
      style: const TextStyle(fontSize: 13),
    );
  },
),
const SizedBox(width: 4),


                      IconButton(
                        icon: Icon(
                          _liked ? Icons.favorite : Icons.favorite_border,
                          color: _liked ? Colors.red : null,
                        ),
                        onPressed: _toggleLike,
                      ),

                      IconButton(
                        icon: Icon(
                          _isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_border_outlined,
                        ),
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

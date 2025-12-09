// lib/feed_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'models/recipe.dart';
import 'pages/view_recipe_page.dart';
import 'pages/view_profile_page.dart';
import 'services/user_service.dart';

String timeAgo(DateTime? dt) {
  if (dt == null) return "";
  final diff = DateTime.now().difference(dt);

  if (diff.inMinutes < 1) return "just now";
  if (diff.inHours < 1) return "${diff.inMinutes}m ago";
  if (diff.inHours < 24) return "${diff.inHours}h ago";
  if (diff.inDays < 7) return "${diff.inDays}d ago";
  return "${(diff.inDays / 7).floor()}w ago";
}

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final ScrollController controller = ScrollController();
  List<Recipe> recipes = [];
  DocumentSnapshot? lastDoc;
  bool loadingMore = false;

  @override
  void initState() {
    super.initState();
    loadInitial();
    controller.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (controller.position.pixels >
        controller.position.maxScrollExtent - 200) {
      loadMore();
    }
  }

  Future<void> loadInitial() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection("recipes")
          .where("isPublic", isEqualTo: true)
          .orderBy("createdAt", descending: true)
          .limit(10)
          .get();

      setState(() {
        recipes = snap.docs.map((e) => Recipe.fromDoc(e)).toList();
        lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
      });
    } catch (e) {
      debugPrint("Feed initial error: $e");
    }
  }

  Future<void> loadMore() async {
    if (loadingMore || lastDoc == null) return;
    loadingMore = true;

    try {
      final snap = await FirebaseFirestore.instance
          .collection("recipes")
          .where("isPublic", isEqualTo: true)
          .orderBy("createdAt", descending: true)
          .startAfterDocument(lastDoc!)
          .limit(10)
          .get();

      setState(() {
        recipes.addAll(snap.docs.map((e) => Recipe.fromDoc(e)));
        lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
        loadingMore = false;
      });
    } catch (e) {
      debugPrint("Feed loadMore error: $e");
      loadingMore = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      controller: controller,
      itemCount: recipes.length,
      itemBuilder: (_, i) => FeedRecipeCard(recipe: recipes[i]),
    );
  }
}

class FeedRecipeCard extends StatefulWidget {
  final Recipe recipe;
  const FeedRecipeCard({super.key, required this.recipe});

  @override
  State<FeedRecipeCard> createState() => _FeedRecipeCardState();
}

class _FeedRecipeCardState extends State<FeedRecipeCard> {
  Map<String, dynamic>? user;
  int currentImage = 0;

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    final u = await UserService.getUser(widget.recipe.authorId);
    if (!mounted) return;
    setState(() => user = u);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final images = r.imageUrls;

    return Card(
      margin: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  user?["photo"] != null ? NetworkImage(user!["photo"]) : null,
              child:
                  user?["photo"] == null ? const Icon(Icons.person) : null,
            ),
            title: Text(
              user?["displayName"] ??
                  user?["username"] ??
                  "Unknown User",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(timeAgo(r.createdAt)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ViewProfilePage(userId: r.authorId),
                ),
              );
            },
          ),

          // IMAGES
          if (images.isNotEmpty)
            GestureDetector(
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ViewRecipePage(recipe: r)));
              },
              child: images.length == 1
                  ? Image.network(images.first, height: 260, fit: BoxFit.cover)
                  : Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        SizedBox(
                          height: 260,
                          child: PageView.builder(
                            itemCount: images.length,
                            onPageChanged: (i) =>
                                setState(() => currentImage = i),
                            itemBuilder: (_, i) =>
                                Image.network(images[i], fit: BoxFit.cover),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            images.length,
                            (i) => Container(
                              margin: const EdgeInsets.all(3),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: currentImage == i
                                    ? Colors.white
                                    : Colors.white54,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(r.title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),

          if (r.description != null && r.description!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(r.description!),
            ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.orange, size: 18),
                const SizedBox(width: 4),
                Text(
                  "${r.averageRating.toStringAsFixed(1)} (${r.ratingCount})",
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


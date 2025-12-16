// lib/public_profile_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'moderation/report_ui.dart';
import 'moderation/report_service.dart';

import 'models/recipe.dart';
import 'pages/view_recipe_page.dart';
import 'pages/follow_lists_page.dart'; // ✅ ONLY this one

String? _pickFirstString(Map<String, dynamic>? data, List<String> keys) {
  if (data == null) return null;
  for (final k in keys) {
    final v = data[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

bool _isHttpUrl(String s) => s.startsWith("http://") || s.startsWith("https://");
bool _isGsUrl(String s) => s.startsWith("gs://");
bool _isDataUrl(String s) => s.startsWith("data:"); // ✅ NEW (fixes terminal URI error)

class PublicProfilePage extends StatelessWidget {
  final String uid;
  const PublicProfilePage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection("users").doc(uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data!.data() ?? {};
        final displayName = user["displayName"] ?? "Unknown";
        final username = user["username"] ?? "";
        final bio = user["bio"] ?? "";

        // ✅ FIX #1: your field is `showSaved`, not `showSavedRecipes`
        // (keep fallback for older docs)
        final showSaved = (user["showSaved"] == true) || (user["showSavedRecipes"] == true);

        final photoAny = _pickFirstString(user, const [
          "photo",
          "photoUrl",
          "photoURL",
          "profilePhotoUrl",
          "profilePictureUrl",
          "avatarUrl",
          "avatar",
        ]);

        final bool isMe = me != null && me.uid == uid;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(displayName.toString()),
              actions: [
                // ✅ Report menu (only when viewing someone else)
                if (!isMe)
                  PopupMenuButton<String>(
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: 'report',
                        child: Text('Report user'),
                      ),
                    ],
                    onSelected: (v) async {
                      if (v == 'report') {
                        await ReportUI.openReportSheet(
                          context,
                          title: 'Report user',
                          target: ReportTarget.user(userId: uid),
                        );
                      }
                    },
                  ),
              ],
            ),
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Center(
                            child: _UserAvatar(photoAny: photoAny, radius: 48),
                          ),
                          const SizedBox(height: 16),

                          Text(
                            displayName.toString(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          Text(
                            "@$username",
                            style: TextStyle(color: Colors.brown.shade600),
                            textAlign: TextAlign.center,
                          ),

                          if (bio.toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              bio.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],

                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection("users")
                                    .doc(uid)
                                    .collection("followers")
                                    .snapshots(),
                                builder: (context, snap) {
                                  final count = snap.data?.docs.length ?? 0;
                                  return InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => FollowListsPage(
                                            uid: uid,
                                            initialIndex: 0,
                                            isOwner: isMe, // ✅ nicer
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      child: Column(
                                        children: [
                                          Text(
                                            "$count",
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const Text(
                                            "Followers",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection("users")
                                    .doc(uid)
                                    .collection("following")
                                    .snapshots(),
                                builder: (context, snap) {
                                  final count = snap.data?.docs.length ?? 0;
                                  return InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => FollowListsPage(
                                            uid: uid,
                                            initialIndex: 1,
                                            isOwner: isMe, // ✅ nicer
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      child: Column(
                                        children: [
                                          Text(
                                            "$count",
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const Text(
                                            "Following",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          if (me != null && me.uid != uid)
                            _FollowButton(myUid: me.uid, viewedUid: uid),

                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabHeaderDelegate(
                      TabBar(
                        tabs: const [
                          Tab(icon: Icon(Icons.grid_on)),
                          Tab(icon: Icon(Icons.bookmark_border)),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  _PostsTab(uid: uid),
                  _SavedTab(uid: uid, showSaved: showSaved),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PostsTab extends StatelessWidget {
  final String uid;
  const _PostsTab({required this.uid});

  String? _coverFromImageUrls(Map<String, dynamic> data) {
    final urls = data["imageUrls"];
    if (urls is List && urls.isNotEmpty) {
      final first = urls.first;
      if (first is String && first.trim().isNotEmpty && !_isDataUrl(first.trim())) {
        return first.trim();
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("recipes")
          .where("authorId", isEqualTo: uid)
          .where("isPublic", isEqualTo: true)
          .orderBy("createdAt", descending: true)
          .limit(60)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("No recipes yet."));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final coverUrl = _coverFromImageUrls(data);
            final title = (data["title"] ?? "Recipe").toString();

            return InkWell(
              onTap: () {
                final recipe = Recipe.fromDoc(doc);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ViewRecipePage(recipe: recipe)),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  color: Colors.brown.shade100,
                  child: coverUrl == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                      : Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.brown.shade100,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SavedTab extends StatelessWidget {
  final String uid;
  final bool showSaved;

  const _SavedTab({required this.uid, required this.showSaved});

  String? _coverFromImageUrls(Map<String, dynamic> data) {
    final urls = data["imageUrls"];
    if (urls is List && urls.isNotEmpty) {
      final first = urls.first;
      if (first is String && first.trim().isNotEmpty && !_isDataUrl(first.trim())) {
        return first.trim();
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!showSaved) {
      return const Center(child: Text("Saved recipes are private."));
    }

    // ✅ FIX #2: Some accounts store saves in `saved_recipes`, others in `savedRecipes`.
    // We'll try `savedRecipes` first, and if it's empty (or errors), fall back to `saved_recipes`.
    return _SavedGridWithFallback(uid: uid);
  }
}

class _SavedGridWithFallback extends StatelessWidget {
  final String uid;
  const _SavedGridWithFallback({required this.uid});

  @override
  Widget build(BuildContext context) {
    final primary = FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("savedRecipes")
        .orderBy("savedAt", descending: true)
        .limit(60)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: primary,
      builder: (context, snap) {
        final hasPrimaryData = snap.hasData && (snap.data?.docs.isNotEmpty ?? false);
        final primaryErrored = snap.hasError;

        if (hasPrimaryData) {
          return _SavedGridFromSavedDocs(savedDocs: snap.data!.docs);
        }

        // fallback collection:
        final fallback = FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("saved_recipes")
            .orderBy("savedAt", descending: true)
            .limit(60)
            .snapshots();

        return StreamBuilder<QuerySnapshot>(
          stream: fallback,
          builder: (context, fbSnap) {
            if (!fbSnap.hasData) {
              // if primary errored, this still shows loading then either data or empty
              return const Center(child: CircularProgressIndicator());
            }

            final savedDocs = fbSnap.data!.docs;
            if (savedDocs.isEmpty) {
              // if primary errored, this might still be empty because of rules — but at least UI is correct now
              return Center(
                child: Text(primaryErrored ? "Can't load saved recipes." : "No saved recipes."),
              );
            }

            return _SavedGridFromSavedDocs(savedDocs: savedDocs);
          },
        );
      },
    );
  }
}

class _SavedGridFromSavedDocs extends StatelessWidget {
  final List<QueryDocumentSnapshot> savedDocs;
  const _SavedGridFromSavedDocs({required this.savedDocs});

  String? _coverFromImageUrls(Map<String, dynamic> data) {
    final urls = data["imageUrls"];
    if (urls is List && urls.isNotEmpty) {
      final first = urls.first;
      if (first is String && first.trim().isNotEmpty && !_isDataUrl(first.trim())) {
        return first.trim();
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemCount: savedDocs.length,
      itemBuilder: (context, i) {
        final data = savedDocs[i].data() as Map<String, dynamic>;
        final recipeId = (data["recipeId"] ?? savedDocs[i].id).toString();

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection("recipes").doc(recipeId).get(),
          builder: (context, recipeSnap) {
            if (!recipeSnap.hasData) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  color: Colors.brown.shade100,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            }

            if (!recipeSnap.data!.exists) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  color: Colors.brown.shade100,
                  child: const Center(child: Text("Missing")),
                ),
              );
            }

            final recipeData = recipeSnap.data!.data() ?? {};
            final coverUrl = _coverFromImageUrls(recipeData);
            final title = (recipeData["title"] ?? "Recipe").toString();
            final recipeDoc = recipeSnap.data!;

            return InkWell(
              onTap: () {
                final recipe = Recipe.fromDoc(recipeDoc);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ViewRecipePage(recipe: recipe)),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  color: Colors.brown.shade100,
                  child: coverUrl == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                      : Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.brown.shade100,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabHeaderDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabHeaderDelegate oldDelegate) => false;
}

class _FollowButton extends StatefulWidget {
  final String myUid;
  final String viewedUid;

  const _FollowButton({required this.myUid, required this.viewedUid});

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _following = false;

  @override
  void initState() {
    super.initState();
    _loadFollowState();
  }

  Future<void> _loadFollowState() async {
    try {
      final ref = FirebaseFirestore.instance
          .collection("users")
          .doc(widget.viewedUid)
          .collection("followers")
          .doc(widget.myUid);

      final snap = await ref.get();
      if (!mounted) return;

      setState(() => _following = snap.exists);
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    final followerRef = FirebaseFirestore.instance
        .collection("users")
        .doc(widget.viewedUid)
        .collection("followers")
        .doc(widget.myUid);

    final followingRef = FirebaseFirestore.instance
        .collection("users")
        .doc(widget.myUid)
        .collection("following")
        .doc(widget.viewedUid);

    final batch = FirebaseFirestore.instance.batch();

    try {
      if (_following) {
        batch.delete(followerRef);
        batch.delete(followingRef);
      } else {
        batch.set(followerRef, {"followedAt": Timestamp.now()});
        batch.set(followingRef, {"followedAt": Timestamp.now()});
      }

      await batch.commit();

      if (mounted) setState(() => _following = !_following);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: _toggleFollow,
      child: Text(_following ? "Unfollow" : "Follow"),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String? photoAny;
  final double radius;

  const _UserAvatar({required this.photoAny, required this.radius});

  Widget _placeholder() {
    return CircleAvatar(
      radius: radius,
      child: Icon(Icons.person, size: radius + 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = photoAny?.trim();

    if (p == null || p.isEmpty) return _placeholder();

    // ✅ avoids "No host specified in URI" for data:image/... strings
    if (_isDataUrl(p)) return _placeholder();

    if (_isHttpUrl(p)) {
      return SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: ClipOval(
          child: Image.network(
            p,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(),
          ),
        ),
      );
    }

    Future<String> resolve() async {
      if (_isGsUrl(p)) {
        return FirebaseStorage.instance.refFromURL(p).getDownloadURL();
      }
      return FirebaseStorage.instance.ref(p).getDownloadURL();
    }

    return FutureBuilder<String>(
      future: resolve(),
      builder: (context, snap) {
        final url = snap.data;
        if (url == null || url.isEmpty) return _placeholder();

        return SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: ClipOval(
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            ),
          ),
        );
      },
    );
  }
}

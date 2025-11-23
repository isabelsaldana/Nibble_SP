// lib/feed_page.dart - CORRECTED

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'models/recipe.dart';
import 'pages/view_recipe_page.dart';
import 'services/saved_service.dart';
import 'pages/view_profile_page.dart'; 

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
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }

    // 1. Stream for the current user's data to watch their 'following' list
    final userStream = FirebaseFirestore.instance.collection('users').doc(me.uid).snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userStream,
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = userSnap.data!.data() ?? {};
        final following = (userData['following'] as List<dynamic>?)?.cast<String>() ?? [];
        
        // 2. Build the recipe query (typed)
        Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('recipes');

        // MODIFIED: Always query for all public recipes to prevent blank feed.
        query = query.where('isPublic', isEqualTo: true);

        // Apply sorting and limit
        final stream = query.orderBy('createdAt', descending: true).limit(50).snapshots();

        // 3. The inner StreamBuilder uses the dynamically created stream
        return Scaffold(
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data?.docs ?? [];
              final recipes = docs.map((d) => Recipe.fromFirestore(d)).toList();

              if (recipes.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No public recipes have been posted yet. Start by posting one!',
                    ),
                  ),
                );
              }

              return Column( // <-- Use Column to stack the following bar and the list
                children: [
                  // NEW: Horizontal list of followed users at the top
                  if (following.isNotEmpty)
                    _FollowingBar(followingUids: following),
                  
                  // Expanded to take the rest of the space
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      itemCount: recipes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final r = recipes[index];
                        return _FeedRecipeCard(recipe: r);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// NEW: Widget to display followed users in a horizontal list
class _FollowingBar extends StatelessWidget {
  const _FollowingBar({required this.followingUids});
  final List<String> followingUids;

  @override
  Widget build(BuildContext context) {
    if (followingUids.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 72, // Fixed height for the horizontal list
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: followingUids.length,
        itemBuilder: (context, index) {
          final uid = followingUids[index];
          // Use a FutureBuilder to fetch the user's data (displayName, photoUrl)
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
              builder: (context, snap) {
                final data = snap.data?.data() as Map<String, dynamic>?;
                final photoUrl = data?['photoUrl'] as String?;
                final displayName = data?['displayName'] ?? data?['username'] ?? 'User';

                return GestureDetector(
                  onTap: () {
                    // Navigate to the user's profile page
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ViewProfilePage(uid: uid),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: photoUrl?.isNotEmpty == true
                            ? NetworkImage(photoUrl!)
                            : null,
                        child: photoUrl?.isEmpty != false
                            ? const Icon(Icons.person, size: 28)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayName.toString().split(' ').first, // Show just the first name/word
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}


class _FeedRecipeCard extends StatefulWidget {
// ... (rest of _FeedRecipeCard class remains the same)
// ... (the existing code for _FeedRecipeCard will be here)
  const _FeedRecipeCard({required this.recipe});
  final Recipe recipe;

  @override
  State<_FeedRecipeCard> createState() => _FeedRecipeCardState();
}

class _FeedRecipeCardState extends State<_FeedRecipeCard> {
  bool _loading = false;
  bool _isSaved = false;

  String? _uploaderDisplayName;
  String? _uploaderPhotoUrl; // <--- NEW: Photo URL
  final _users = FirebaseFirestore.instance.collection('users');

  @override
  void initState() {
    super.initState();
    _checkSaved();
    _fetchUploaderName();
  }

  // UPDATED: Function to fetch the uploader's name AND photo URL
  Future<void> _fetchUploaderName() async {
    final uid = widget.recipe.authorId;
    if (uid.isEmpty) return;

    final snap = await _users.doc(uid).get();
    final data = snap.data();

    if (data != null && mounted) {
      setState(() {
        _uploaderDisplayName = data['displayName'] ?? data['username'] ?? 'Anonymous';
        _uploaderPhotoUrl = data['photoUrl'] as String?; // <--- NEW: Get photoUrl
      });
    }
  }

  Future<void> _checkSaved() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final isSaved = await SavedService().isSaved(uid: me.uid, recipeId: widget.recipe.id);
    if (mounted) setState(() => _isSaved = isSaved);
  }

  void _onSavePressed() async {
    // ... (existing implementation)
    if (_loading) return;
    setState(() => _loading = true);

    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      if (mounted) setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to save recipes')));
      return;
    }

    if (_isSaved) {
      final confirmed = await _showSaveBottomSheet(context, 'Unsave recipe?') ?? false;
      if (confirmed) {
        await SavedService().removeSaved(uid: me.uid, recipeId: widget.recipe.id);
      }
    } else {
      await SavedService().toggleSaved(uid: me.uid, recipe: widget.recipe);
    }

    await _checkSaved();
    if (mounted) setState(() => _loading = false);
  }

  Future<bool?> _showSaveBottomSheet(BuildContext context, String title) {
    // ... (existing implementation)
    return showModalBottomSheet<bool?>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build a small profile avatar for the feed item
  Widget _buildAvatar() {
    if (_uploaderPhotoUrl?.isNotEmpty == true) {
      return CircleAvatar(
        radius: 12, // smaller size for feed
        backgroundImage: NetworkImage(_uploaderPhotoUrl!),
      );
    }
    return const CircleAvatar(
      radius: 12,
      child: Icon(Icons.person, size: 16),
    );
  }


  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ViewRecipePage(recipe: r),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image (if available)
            if (r.imageUrls.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Image.network(
                  r.imageUrls.first,
                  height: 220,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 220,
                      color: cs.surface,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    r.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Uploader Name + Time ago + Action buttons
                  Row(
                    children: [
                      // Uploader Avatar - NEW
                      _buildAvatar(),
                      const SizedBox(width: 8),

                      // Uploader Name (Tappable)
                      GestureDetector(
                        onTap: () {
                          // Navigate to the uploader's profile page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ViewProfilePage(uid: r.authorId),
                            ),
                          );
                        },
                        child: Text(
                          _uploaderDisplayName ?? 'Loading...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.brown.shade400,
                            fontWeight: FontWeight.w600,
                          ),
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
                      IconButton(
                        icon: const Icon(Icons.favorite_border_outlined),
                        onPressed: () {
                          // later: hook up likes
                        },
                      ),
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
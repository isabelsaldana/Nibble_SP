// lib/search_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'models/recipe.dart';
import 'pages/view_recipe_page.dart';

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

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _query = _controller.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('recipes')
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: stream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error loading recipes: ${snap.error}'),
                    );
                  }

                  if (snap.connectionState == ConnectionState.waiting &&
                      (snap.data == null || snap.data!.docs.isEmpty)) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data?.docs ?? [];

                  // Convert to Recipe objects AND compute search scores
                  final List<_ScoredRecipe> hits = [];

                  for (final doc in docs) {
                    final recipe = Recipe.fromFirestore(doc);
                    final data = doc.data();

                    int score = 0;
                    if (_query.isNotEmpty) {
                      final blob = _buildSearchBlob(data);
                      score = _scoreForBlob(blob, _query);
                    }

                    hits.add(_ScoredRecipe(recipe: recipe, score: score));
                  }

                  List<_ScoredRecipe> visibleHits;

                  if (_query.isEmpty) {
                    // No search: show everything in Firestore order (newest first)
                    visibleHits = hits;
                  } else {
                    // Only recipes that matched at least once
                    visibleHits =
                        hits.where((h) => h.score > 0).toList()
                          ..sort((a, b) => b.score.compareTo(a.score));
                  }

                  if (visibleHits.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _query.isEmpty
                              ? 'Start typing to search recipes.'
                              : 'No recipes found for "$_query".',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 3 / 4,
                    ),
                    itemCount: visibleHits.length,
                    itemBuilder: (context, index) {
                      final hit = visibleHits[index];
                      final r = hit.recipe;
                      final imageUrl =
                          r.imageUrls.isNotEmpty ? r.imageUrls.first : null;

                      return _SearchResultTile(recipe: r, imageUrl: imageUrl);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.brown.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.brown.shade100),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Search recipes…',
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
              ),
            ),
            if (_query.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _controller.clear();
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Simple holder for recipe + score
class _ScoredRecipe {
  final Recipe recipe;
  final int score;

  _ScoredRecipe({required this.recipe, required this.score});
}

/// Build one big text blob from all relevant fields in the Firestore doc.
String _buildSearchBlob(Map<String, dynamic> data) {
  final parts = <String>[];

  void addString(dynamic v) {
    if (v is String && v.trim().isNotEmpty) {
      parts.add(v);
    }
  }

  void addList(dynamic v) {
    if (v is List) {
      for (final item in v) {
        if (item is String && item.trim().isNotEmpty) {
          parts.add(item);
        }
      }
    }
  }

  addString(data['title']);
  addString(data['description']);

  // ingredients: list of strings
  addList(data['ingredients']);

  // steps: could be list or string
  final steps = data['steps'];
  if (steps is String) {
    addString(steps);
  } else {
    addList(steps);
  }

  // tags: list of strings, if you use them
  addList(data['tags']);

  // You can add more fields here if you want them searchable,
  // e.g. data['difficulty'], data['notes'], etc.

  return parts.join('\n').toLowerCase();
}

/// Score = how many times ANY of the query words appear in the blob.
int _scoreForBlob(String blob, String query) {
  final words = query
      .split(RegExp(r'\s+'))
      .map((w) => w.trim())
      .where((w) => w.isNotEmpty)
      .toList();

  if (words.isEmpty) return 0;

  int score = 0;
  for (final w in words) {
    score += _countOccurrences(blob, w);
  }
  return score;
}

int _countOccurrences(String text, String term) {
  if (term.isEmpty) return 0;
  int count = 0;
  int index = text.indexOf(term);
  while (index != -1) {
    count++;
    index = text.indexOf(term, index + term.length);
  }
  return count;
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.recipe,
    required this.imageUrl,
  });

  final Recipe recipe;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
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

            // Title + optional time
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (recipe.createdAt != null)
                    Text(
                      _timeAgo(recipe.createdAt),
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

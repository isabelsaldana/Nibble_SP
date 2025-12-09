// lib/search_page.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'models/recipe.dart';
import 'pages/view_recipe_page.dart';
import 'services/user_service.dart'; // ⭐ REQUIRED for profile search

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
  String _query = "";

  List<String> _suggestions = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final text = _controller.text.trim().toLowerCase();

      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() => _query = text);
        _updateSuggestions(text);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ⭐ Suggestions from title, tags, ingredients
  Future<void> _updateSuggestions(String q) async {
    if (q.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection('recipes')
        .where("isPublic", isEqualTo: true)
        .limit(10)
        .get();

    final Set<String> words = {};

    for (final doc in snap.docs) {
      final d = doc.data();

      void add(dynamic v) {
        if (v is String) words.addAll(v.toLowerCase().split(" "));
        if (v is List) {
          for (final x in v) {
            if (x is String) words.addAll(x.toLowerCase().split(" "));
          }
        }
      }

      add(d["title"]);
      add(d["tags"]);
      add(d["ingredients"]);
    }

    setState(() {
      _suggestions = words
          .where((w) => w.startsWith(q) && w.length > q.length)
          .take(6)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final recipeStream = FirebaseFirestore.instance
        .collection("recipes")
        .where("isPublic", isEqualTo: true)
        .orderBy("createdAt", descending: true)
        .snapshots();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),

            if (_suggestions.isNotEmpty)
              _buildSuggestionDropdown(),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: recipeStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data?.docs ?? [];

                  final List<_ScoredRecipe> results = [];

                  for (final d in docs) {
                    final recipe = Recipe.fromFirestore(d);
                    final data = d.data();

                    final blob = _buildBlob(data);
                    final score = _score(blob, _query);

                    if (_query.isEmpty || score > 0) {
                      results.add(_ScoredRecipe(recipe, score));
                    }
                  }

                  if (_query.isNotEmpty && results.isEmpty) {
                    return _tryProfileSearch();
                  }

                  if (_query.isNotEmpty) {
                    results.sort((a, b) => b.score.compareTo(a.score));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: results.length,
                    itemBuilder: (_, i) {
                      final r = results[i].recipe;
                      return _RecipeListTile(recipe: r);
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

  // ⭐ SEARCH BAR
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.brown.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.brown.shade100),
        ),
        child: Row(
          children: [
            const Icon(Icons.search),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Search recipes, tags, ingredients, profiles…",
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() {
                  _controller.clear();
                  _query = "";
                }),
              ),
          ],
        ),
      ),
    );
  }

  // ⭐ DROPDOWN SUGGESTIONS
  Widget _buildSuggestionDropdown() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(10),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _suggestions.length,
          itemBuilder: (_, i) {
            final s = _suggestions[i];
            return ListTile(
              title: Text(s),
              onTap: () {
                _controller.text = s;
                setState(() {
                  _query = s;
                  _suggestions = [];
                });
              },
            );
          },
        ),
      ),
    );
  }

  /* ---------------------------------------------------------
     ⭐ If no recipes match, try username search instantly
     --------------------------------------------------------- */
  Widget _tryProfileSearch() {
    return StreamBuilder(
      stream: UserService.searchUsers(_query),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return Center(
            child: Text('No results for "$_query"'),
          );
        }

        final users = snap.data!;

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (_, i) {
            final u = users[i];
            return ListTile(
              leading: u["photo"] != null
                  ? CircleAvatar(backgroundImage: NetworkImage(u["photo"]))
                  : const CircleAvatar(child: Icon(Icons.person)),
              title: Text(u["username"] ?? "Unknown"),
              subtitle: Text(u["id"]),
            );
          },
        );
      },
    );
  }
}

/* ---------------------------------------------------------
   ⭐ SIMPLE LIST TILE (NO IMAGES IN SEARCH RESULTS)
   --------------------------------------------------------- */

class _RecipeListTile extends StatelessWidget {
  final Recipe recipe;
  const _RecipeListTile({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(recipe.title),
        subtitle: Text(
          recipe.tags.isNotEmpty
              ? recipe.tags.map((t) => "#$t").join("  ")
              : "No tags",
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ViewRecipePage(recipe: recipe),
            ),
          );
        },
      ),
    );
  }
}

/* ---------------------------------------------------------
   ⭐ SEARCH SCORING SYSTEM
   --------------------------------------------------------- */

String _buildBlob(Map<String, dynamic> d) {
  final parts = <String>[];

  void add(dynamic v) {
    if (v is String) parts.add(v);
    if (v is List) {
      for (final x in v) {
        if (x is String) parts.add(x);
      }
    }
  }

  add(d["title"]);
  add(d["description"]);
  add(d["ingredients"]);
  add(d["steps"]);
  add(d["tags"]);

  return parts.join(" ").toLowerCase();
}

int _score(String blob, String query) {
  if (query.isEmpty) return 0;

  int score = 0;
  for (final part in query.split(" ")) {
    if (part.isEmpty) continue;
    score += _count(blob, part);
  }
  return score;
}

int _count(String text, String term) {
  int count = 0;
  int index = text.indexOf(term);
  while (index != -1) {
    count++;
    index = text.indexOf(term, index + term.length);
  }
  return count;
}

class _ScoredRecipe {
  final Recipe recipe;
  final int score;
  _ScoredRecipe(this.recipe, this.score);
}

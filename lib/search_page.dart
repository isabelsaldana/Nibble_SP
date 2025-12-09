// lib/search_page.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'public_profile_page.dart';
import 'models/recipe.dart';
import 'pages/view_recipe_page.dart';
import 'services/user_service.dart';

class SearchPage extends StatefulWidget {
  final String? initialQuery;

  const SearchPage({super.key, this.initialQuery});

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

    if (widget.initialQuery != null) {
      _controller.text = widget.initialQuery!;
      _query = widget.initialQuery!.toLowerCase();
    }

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

  Future<void> _updateSuggestions(String q) async {
    if (q.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection("recipes")
        .where("isPublic", isEqualTo: true)
        .limit(25)
        .get();

    final words = <String>{};

    for (final doc in snap.docs) {
      final d = doc.data();

      void add(dynamic v) {
        if (v is String) {
          words.addAll(v.toLowerCase().split(" "));
        } else if (v is List) {
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
          .take(8)
          .toList();
    });
  }

  bool _matchesUser(Map<String, dynamic> u, String q) {
    if (q.isEmpty) return false;
    q = q.toLowerCase();

    return u["usernameLower"]?.toString().contains(q) == true ||
        u["displayName"]?.toString().toLowerCase().contains(q) == true;
  }

  @override
  Widget build(BuildContext context) {
    final recipeStream = FirebaseFirestore.instance
        .collection("recipes")
        .where("isPublic", isEqualTo: true)
        .orderBy("createdAt", descending: true)
        .snapshots();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),

            if (_suggestions.isNotEmpty) _buildSuggestionDropdown(),

            Expanded(
              child: StreamBuilder(
                stream: recipeStream,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs;
                  final List<_Hit> results = [];

                  for (final d in docs) {
                    final recipe = Recipe.fromFirestore(d);
                    final data = d.data();

                    final blob = _blob(data);
                    final score = _score(blob, _query);

                    if (_query.isEmpty || score > 0) {
                      results.add(_Hit(recipe, score));
                    }
                  }

                  if (_query.isNotEmpty) {
                    results.sort((a, b) => b.score.compareTo(a.score));
                  }

                  return StreamBuilder(
                    stream: UserService.searchUsers(_query),
                    builder: (context, userSnap) {
                      final users = (userSnap.data ?? [])
                          .where((u) => _matchesUser(u, _query))
                          .toList();

                      return ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          if (users.isNotEmpty) _buildUserResults(users),

                          if (results.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 6, top: 12),
                              child: Text(
                                "Recipes",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.brown.shade700,
                                  fontSize: 16,
                                ),
                              ),
                            ),

                          ...results.map((hit) => _RecipeTile(recipe: hit.recipe)),

                          if (_query.isNotEmpty &&
                              users.isEmpty &&
                              results.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text('No results for "$_query"'),
                              ),
                            ),
                        ],
                      );
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
                  hintText: "Search recipes, tags, profiles…",
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  setState(() => _query = "");
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionDropdown() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
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

  Widget _buildUserResults(List users) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 6, bottom: 4),
          child: Text(
            "Profiles",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        ...users.map((u) {
          final username = u["username"];
          final displayName = u["displayName"] ?? username;
          final photo = u["photo"];

          return Card(
            child: ListTile(
              leading: photo != null
                  ? CircleAvatar(backgroundImage: NetworkImage(photo))
                  : const CircleAvatar(child: Icon(Icons.person)),
              title: Text(displayName),
              subtitle: Text("@$username"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PublicProfilePage(uid: u["id"]),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

class _RecipeTile extends StatelessWidget {
  final Recipe recipe;

  const _RecipeTile({required this.recipe});

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

String _blob(Map<String, dynamic> d) {
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
  for (final word in query.split(" ")) {
    if (word.isNotEmpty) score += _count(blob, word);
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

class _Hit {
  final Recipe recipe;
  final int score;
  _Hit(this.recipe, this.score);
}

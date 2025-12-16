// lib/search_page.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'models/recipe.dart';
import 'pages/view_recipe_page.dart';
import 'public_profile_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    this.initialQuery,
  });

  final String? initialQuery;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final TextEditingController _searchCtrl;

  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);

    _searchCtrl = TextEditingController(text: widget.initialQuery ?? '');
    _query = (widget.initialQuery ?? '').trim();

    // If they open search with "#tag", default to For you tab.
    // If they open with "@something" you could switch to Accounts tab if you want.
    if (_query.startsWith('@')) {
      _tabs.index = 1;
    } else {
      _tabs.index = 0;
    }

    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 180), () {
        if (!mounted) return;
        setState(() => _query = _searchCtrl.text.trim());
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _setQuery(String q) {
    _searchCtrl.text = q;
    _searchCtrl.selection =
        TextSelection.fromPosition(TextPosition(offset: q.length));
    setState(() => _query = q.trim());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          // IG-like search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.brown.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.brown.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(Icons.search, size: 20, color: Colors.brown.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search recipes, tags, profiles…',
                        hintStyle: TextStyle(color: Colors.brown.shade400),
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear',
                      onPressed: () => _setQuery(''),
                      icon: Icon(Icons.close,
                          size: 18, color: Colors.brown.shade600),
                    )
                  else
                    const SizedBox(width: 8),
                ],
              ),
            ),
          ),

          // Tabs (like IG)
          TabBar(
            controller: _tabs,
            labelColor: cs.primary,
            unselectedLabelColor: Colors.brown.shade400,
            indicatorColor: cs.primary,
            tabs: const [
              Tab(text: 'For you'),
              Tab(text: 'Accounts'),
              Tab(text: 'Tags'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ForYouGrid(
                  query: _query,
                  onOpenTag: (tag) {
                    _tabs.index = 2;
                    _setQuery('#$tag');
                  },
                ),
                _AccountsList(query: _query),
                _TagsList(
                  query: _query,
                  onPickTag: (tag) {
                    _tabs.index = 0;
                    _setQuery('#$tag');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ForYouGrid extends StatelessWidget {
  const _ForYouGrid({
    required this.query,
    required this.onOpenTag,
  });

  final String query;
  final void Function(String tag) onOpenTag;

  bool _containsCI(String a, String b) =>
      a.toLowerCase().contains(b.toLowerCase());

  List<String> _asStringList(dynamic v) {
    if (v is List) {
      return v
          .where((e) => e != null)
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (v is String && v.trim().isNotEmpty) return [v.trim()];
    return <String>[];
  }

  List<String> _stepsToList(dynamic v) {
    if (v is List) return _asStringList(v);
    if (v is String && v.trim().isNotEmpty) return [v.trim()];
    return <String>[];
  }

  List<String> _queryTokens(String q) {
    return q
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.trim().isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('recipes')
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        final q = query.trim();
        final isTag = q.startsWith('#') && q.length > 1;
        final tag = isTag ? q.substring(1).trim() : '';

        final filtered = docs.where((d) {
          final data = d.data();
          final title = (data['title'] ?? '').toString();
          final desc = (data['description'] ?? '').toString();

          final tags = _asStringList(data['tags']);
          final ingredients = _asStringList(data['ingredients']);
          final steps = _stepsToList(data['steps']);

          // ✅ optional index (newer recipes will have this)
          final searchIndex = _asStringList(data['searchIndex'])
              .map((s) => s.toLowerCase())
              .toList();

          if (q.isEmpty) return true;

          if (isTag) {
            return tags.any((t) => t.toLowerCase() == tag.toLowerCase());
          }

          // ✅ Token-based match: "almond milk" works better than one big contains()
          final tokens = _queryTokens(q);

          bool tokenMatch(String tok) {
            if (_containsCI(title, tok) || _containsCI(desc, tok)) return true;
            if (tags.any((t) => _containsCI(t, tok))) return true;

            // ✅ fast match if we have an index
            if (searchIndex.isNotEmpty && searchIndex.any((s) => s.contains(tok))) {
              return true;
            }

            // ✅ fallback for older recipes
            if (ingredients.any((s) => _containsCI(s, tok))) return true;
            if (steps.any((s) => _containsCI(s, tok))) return true;

            return false;
          }

          return tokens.every(tokenMatch);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'No results',
              style: TextStyle(color: Colors.brown.shade400),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 1,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final doc = filtered[i];
            final data = doc.data();

            final title = (data['title'] ?? 'Recipe').toString();

            final imageUrls = _asStringList(data['imageUrls']);
            final cover = imageUrls.isNotEmpty ? imageUrls.first : null;

            final tags = _asStringList(data['tags']);

            return InkWell(
              onTap: () {
                final recipe = Recipe.fromFirestore(doc);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ViewRecipePage(recipe: recipe),
                  ),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover != null)
                    Image.network(
                      cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _TileFallback(title: title),
                    )
                  else
                    _TileFallback(title: title),

                  // subtle gradient overlay (like IG)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.35),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // optional: first tag chip overlay
                  if (tags.isNotEmpty)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: GestureDetector(
                        onTap: () => onOpenTag(tags.first),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '#${tags.first}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TileFallback extends StatelessWidget {
  const _TileFallback({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.brown.withOpacity(0.12),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.brown.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountsList extends StatelessWidget {
  const _AccountsList({required this.query});
  final String query;

  bool _containsCI(String a, String b) =>
      a.toLowerCase().contains(b.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final q = query.trim().replaceFirst('@', '');

    final stream = FirebaseFirestore.instance.collection('users').limit(200).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;

        final filtered = docs.where((d) {
          if (q.isEmpty) return true;
          final data = d.data();
          final username = (data['username'] ?? '').toString();
          final displayName = (data['displayName'] ?? '').toString();
          return _containsCI(username, q) || _containsCI(displayName, q);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'No accounts found',
              style: TextStyle(color: Colors.brown.shade400),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: Colors.brown.withOpacity(0.12)),
          itemBuilder: (context, i) {
            final doc = filtered[i];
            final data = doc.data();

            final username = (data['username'] ?? '').toString();
            final displayName = (data['displayName'] ?? username).toString();
            final bio = (data['bio'] ?? '').toString();

            final photo = (data['photo'] ?? data['photoUrl'] ?? data['photoURL'])
                ?.toString()
                .trim();
            final hasPhoto = photo != null && photo.isNotEmpty;

            return ListTile(
              leading: CircleAvatar(
                radius: 22,
                backgroundImage: hasPhoto ? NetworkImage(photo!) : null,
                child: !hasPhoto ? const Icon(Icons.person) : null,
              ),
              title: Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (username.isNotEmpty)
                    Text('@$username',
                        style: TextStyle(color: Colors.brown.shade500)),
                  if (bio.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        bio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PublicProfilePage(uid: doc.id)),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _TagsList extends StatelessWidget {
  const _TagsList({
    required this.query,
    required this.onPickTag,
  });

  final String query;
  final void Function(String tag) onPickTag;

  bool _containsCI(String a, String b) =>
      a.toLowerCase().contains(b.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final q = query.trim();
    final needle = q.startsWith('#') ? q.substring(1).trim() : q;

    final stream = FirebaseFirestore.instance
        .collection('recipes')
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(250)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final counts = <String, int>{};

        for (final doc in snap.data!.docs) {
          final data = doc.data();
          final tagsRaw = data['tags'];
          final tags = (tagsRaw is List)
              ? tagsRaw
                  .map((e) => e.toString())
                  .where((s) => s.trim().isNotEmpty)
                  .toList()
              : <String>[];

          for (final t in tags) {
            counts[t] = (counts[t] ?? 0) + 1;
          }
        }

        var items = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        if (needle.isNotEmpty) {
          items = items.where((e) => _containsCI(e.key, needle)).toList();
        }

        if (items.isEmpty) {
          return Center(
            child: Text(
              'No tags found',
              style: TextStyle(color: Colors.brown.shade400),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          itemCount: items.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: Colors.brown.withOpacity(0.12)),
          itemBuilder: (context, i) {
            final tag = items[i].key;
            final count = items[i].value;

            return ListTile(
              leading: const Icon(Icons.tag),
              title: Text('#$tag',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle:
                  Text('$count recipes', style: TextStyle(color: Colors.brown.shade500)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onPickTag(tag),
            );
          },
        );
      },
    );
  }
}

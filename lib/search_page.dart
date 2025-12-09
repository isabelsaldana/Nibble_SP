// lib/search_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/recipe.dart';
import 'services/user_service.dart';
import 'pages/view_profile_page.dart';
import 'widgets/search_recipe_card.dart';

class SearchPage extends StatefulWidget {
  final String? initialTag;
  const SearchPage({super.key, this.initialTag});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final controller = TextEditingController();
  Timer? debounceTimer;

  String query = "";
  String? activeTag;

  @override
  void initState() {
    super.initState();
    activeTag = widget.initialTag;
  }

  @override
  void dispose() {
    debounceTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  void onQueryChanged(String text) {
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 250), () {
      setState(() {
        query = text.trim().toLowerCase();
        activeTag = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: controller,
          onChanged: onQueryChanged,
          decoration: const InputDecoration(
            hintText: "Search recipes, users, tags, ingredients...",
            border: InputBorder.none,
          ),
        ),
      ),
      body: query.isEmpty && activeTag == null
          ? const Center(child: Text("Start typing to search…"))
          : (activeTag != null ? _tagResults() : _fullSearch()),
    );
  }

  /* ────────────────────────────────────────────────
     TAG FILTER
     ──────────────────────────────────────────────── */

  Widget _tagResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("recipes")
          .where("tagsLower", arrayContains: activeTag!.toLowerCase())
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final list = snap.data!.docs.map((e) => Recipe.fromDoc(e)).toList();
        if (list.isEmpty) {
          return const Center(child: Text("No recipes for this tag."));
        }

        return ListView(
          children: list.map((e) => SearchRecipeCard(recipe: e)).toList(),
        );
      },
    );
  }

  /* ────────────────────────────────────────────────
     FULL SEARCH
     ──────────────────────────────────────────────── */

  Widget _fullSearch() {
    final q = query;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("recipes")
          .where("titleLower", isGreaterThanOrEqualTo: q)
          .where("titleLower", isLessThanOrEqualTo: "$q\uf8ff")
          .snapshots(),
      builder: (_, recipeSnap) {
        final recipes =
            recipeSnap.data?.docs.map((e) => Recipe.fromDoc(e)).toList() ?? [];

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: UserService.searchUsers(q),
          builder: (_, userSnap) {
            final users = userSnap.data ?? [];

            final tagSet = <String>{};
            final ingSet = <String>{};

            for (var r in recipes) {
              for (var t in r.tagsLower) {
                if (t.contains(q)) tagSet.add(t);
              }
              for (var ing in r.ingredientsLower) {
                if (ing.contains(q)) ingSet.add(ing);
              }
            }

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (users.isNotEmpty)
                  const Text("Users",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                ...users.map((u) {
                  final photo = u["photo"]?.toString();
                  final username = u["username"]?.toString() ?? "";
                  final userId = u["id"]?.toString();

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (photo != null && photo.isNotEmpty)
                          ? NetworkImage(photo)
                          : null,
                      child: (photo == null || photo.isEmpty)
                          ? Text(username.isNotEmpty
                              ? username[0].toUpperCase()
                              : "?")
                          : null,
                    ),
                    title: Text(username),
                    onTap: () {
                      if (userId == null || userId.isEmpty) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ViewProfilePage(userId: userId),
                        ),
                      );
                    },
                  );
                }),

                if (tagSet.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: Text("Tags",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ...tagSet.map((t) => ListTile(
                      leading: const Icon(Icons.tag),
                      title: Text("#$t"),
                      onTap: () => setState(() {
                        activeTag = t;
                        controller.clear();
                      }),
                    )),

                if (ingSet.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: Text("Ingredients",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ...ingSet.map((ing) => ListTile(
                      leading: const Icon(Icons.kitchen),
                      title: Text(ing),
                    )),

                if (recipes.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: Text("Recipes",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ...recipes.map((r) => SearchRecipeCard(recipe: r)),
              ],
            );
          },
        );
      },
    );
  }
}

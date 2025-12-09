// lib/pages/view_profile_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recipe.dart';
import '../services/user_service.dart';
import '../widgets/search_recipe_card.dart';

class ViewProfilePage extends StatefulWidget {
  final String userId;
  const ViewProfilePage({super.key, required this.userId});

  @override
  State<ViewProfilePage> createState() => _ViewProfilePageState();
}

class _ViewProfilePageState extends State<ViewProfilePage> {
  Map<String, dynamic>? user;

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    final u = await UserService.getUser(widget.userId);
    if (!mounted) return;
    setState(() => user = u);
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(user!["username"] ?? "User")),
      body: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 45,
            backgroundImage: user!["photo"] != null
                ? NetworkImage(user!["photo"])
                : null,
            child: user!["photo"] == null ? const Icon(Icons.person, size: 50) : null,
          ),
          const SizedBox(height: 12),
          Text(
            user!["displayName"] ?? user!["username"] ?? "",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("recipes")
                  .where("authorId", isEqualTo: widget.userId)
                  .snapshots(),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final recipes =
                    snap.data!.docs.map((e) => Recipe.fromDoc(e)).toList();

                if (recipes.isEmpty) {
                  return const Center(child: Text("No recipes yet."));
                }

                return ListView(
                  children: recipes.map((r) => SearchRecipeCard(recipe: r)).toList(),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

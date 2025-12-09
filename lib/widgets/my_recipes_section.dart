import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/recipe.dart';
import '../pages/view_recipe_page.dart';
import '../widgets/search_recipe_card.dart';

class MyRecipesSection extends StatelessWidget {
  const MyRecipesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("recipes")
          .where("authorId", isEqualTo: uid)
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                "You haven’t posted any recipes yet.",
                style: TextStyle(fontSize: 16),
              ),
            ),
          );
        }

        final recipes = snap.data!.docs
            .map((e) => Recipe.fromDoc(e))
            .toList();

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: recipes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final recipe = recipes[index];

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ViewRecipePage(recipe: recipe),
                  ),
                );
              },
              child: SearchRecipeCard(recipe: recipe),
            );
          },
        );
      },
    );
  }
}

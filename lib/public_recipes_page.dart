// lib/public_recipes_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'models/recipe.dart';
import 'widgets/search_recipe_card.dart';

class PublicRecipesPage extends StatelessWidget {
  const PublicRecipesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("recipes")
          .where("isPublic", isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final list = snap.data!.docs.map((e) => Recipe.fromDoc(e)).toList();

        return ListView(
          padding: const EdgeInsets.all(8),
          children: list.map((e) => SearchRecipeCard(recipe: e)).toList(),
        );
      },
    );
  }
}

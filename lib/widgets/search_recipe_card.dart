// lib/search_recipe_card.dart
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '/pages/view_recipe_page.dart';

class SearchRecipeCard extends StatelessWidget {
  final Recipe recipe;

  const SearchRecipeCard({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(recipe.title),
        subtitle: recipe.ratingCount > 0
            ? Text("⭐ ${recipe.averageRating.toStringAsFixed(1)} (${recipe.ratingCount})")
            : const Text("No ratings yet"),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ViewRecipePage(recipe: recipe)),
          );
        },
      ),
    );
  }
}

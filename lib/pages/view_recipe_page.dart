// lib/pages/view_recipe_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import 'view_profile_page.dart';
import '../search_page.dart';

class ViewRecipePage extends StatefulWidget {
  final Recipe recipe;

  const ViewRecipePage({super.key, required this.recipe});

  @override
  State<ViewRecipePage> createState() => _ViewRecipePageState();
}

class _ViewRecipePageState extends State<ViewRecipePage> {
  int? userRating;
  bool loadingRating = true;

  @override
  void initState() {
    super.initState();
    _loadUserRating();
  }

  Future<void> _loadUserRating() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final rating = await RecipeService.getUserRating(widget.recipe.id, uid);

    setState(() {
      userRating = rating;
      loadingRating = false;
    });
  }

  Future<void> _rate(int value) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    setState(() => userRating = value);

    await RecipeService.rateRecipe(
      recipeId: widget.recipe.id,
      userId: uid,
      rating: value,
    );
  }

  Widget _star(int index) {
    final filled = userRating != null && userRating! >= index;
    return GestureDetector(
      onTap: () => _rate(index),
      child: Icon(
        filled ? Icons.star : Icons.star_border,
        color: Colors.amber,
        size: 32,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;

    return Scaffold(
      appBar: AppBar(
        title: Text(r.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ViewProfilePage(userId: r.authorId),
                ),
              );
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ----------------------------------------------------
          // MAIN IMAGE
          // ----------------------------------------------------
          if (r.imageUrls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(r.imageUrls.first, height: 250, fit: BoxFit.cover),
            ),

          const SizedBox(height: 16),

          // ----------------------------------------------------
          // TITLE + RATING SUMMARY
          // ----------------------------------------------------
          Text(
            r.title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          if (r.ratingCount > 0)
            Text(
              "⭐ ${r.averageRating.toStringAsFixed(1)}  (${r.ratingCount} ratings)",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),

          const SizedBox(height: 12),

          // ----------------------------------------------------
          // USER RATING WIDGET
          // ----------------------------------------------------
          Text("Your rating:", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),

          loadingRating
              ? const CircularProgressIndicator()
              : Row(children: [
                  _star(1),
                  _star(2),
                  _star(3),
                  _star(4),
                  _star(5),
                ]),

          const SizedBox(height: 20),

          // ----------------------------------------------------
          // TAGS (CLICKABLE)
          // ----------------------------------------------------
          Wrap(
            spacing: 8,
            children: r.tags.map((tag) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SearchPage(initialTag: tag),
                    ),
                  );
                },
                child: Chip(
                  label: Text(tag),
                  backgroundColor: Colors.orange.shade100,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // ----------------------------------------------------
          // INGREDIENTS
          // ----------------------------------------------------
          Text("Ingredients", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          ...r.ingredients.map((i) => Text("• $i")),

          const SizedBox(height: 20),

          // ----------------------------------------------------
          // STEPS
          // ----------------------------------------------------
          Text("Steps", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          ...r.steps.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text("• $s"),
              )),
        ],
      ),
    );
  }
}

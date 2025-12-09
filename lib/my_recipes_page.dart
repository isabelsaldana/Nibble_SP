// lib/pages/my_recipes_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/recipe.dart';
import '../services/recipe_service.dart';
import 'pages/view_recipe_page.dart';

class MyRecipesPage extends StatelessWidget {
  const MyRecipesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final svc = RecipeService();

    return Scaffold(
      appBar: AppBar(title: const Text("My Recipes")),
      body: StreamBuilder<List<Recipe>>(
        stream: svc.userRecipes(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final recipes = snap.data ?? [];

          if (recipes.isEmpty) {
            return const Center(
              child: Text("You haven't posted any recipes yet."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: recipes.length,
            itemBuilder: (_, i) {
              final r = recipes[i];
              final imageUrl =
                  r.imageUrls.isNotEmpty ? r.imageUrls.first : null;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ViewRecipePage(recipe: r),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      // ---- Thumbnail ----
                      ClipRRect(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(14),
                        ),
                        child: SizedBox(
                          width: 110,
                          height: 90,
                          child: imageUrl == null
                              ? Container(
                                  color: Colors.brown.shade100,
                                  child: const Icon(Icons.restaurant),
                                )
                              : Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // ---- Title & Description ----
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (r.description != null)
                                Text(
                                  r.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

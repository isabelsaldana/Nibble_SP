// lib/public_recipes_page.dart
import 'package:flutter/material.dart';
import 'models/recipe.dart';
import 'services/recipe_service.dart';
import 'pages/view_recipe_page.dart';

class PublicRecipesPage extends StatelessWidget {
  const PublicRecipesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = RecipeService();

    return Scaffold(
      appBar: AppBar(title: const Text('Public Recipes')),

      // FIX: use publicFeed() instead of publicRecipes()
      body: StreamBuilder<List<Recipe>>(
        stream: svc.publicFeed(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('No public recipes yet.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final r = items[i];
              final img = r.imageUrls.isNotEmpty ? r.imageUrls.first : null;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ViewRecipePage(recipe: r),
                      ),
                    );
                  },

                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: img != null
                        ? Image.network(
                            img,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            color: Colors.brown.shade100,
                            child: const Icon(Icons.restaurant),
                          ),
                  ),

                  title: Text(
                    r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),

                  subtitle: Text(
                    '${r.ingredients.length} ingredients',
                    style: const TextStyle(fontSize: 13),
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

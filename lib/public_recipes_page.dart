import 'package:flutter/material.dart';
import 'models/recipe.dart';
import 'services/recipe_service.dart';

class PublicRecipesPage extends StatelessWidget {
  const PublicRecipesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = RecipeService();
    return Scaffold(
      appBar: AppBar(title: const Text('Public Recipes')),
      body: StreamBuilder<List<Recipe>>(
        stream: svc.publicFeed(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No public recipes yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final r = items[i];
              return Card(
                child: ListTile(
                  leading: (r.imageUrls.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(r.imageUrls.first, width: 48, height: 48, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.restaurant_menu),
                  title: Text(r.title),
                  subtitle: Text('${r.ingredients.length} ingredients'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


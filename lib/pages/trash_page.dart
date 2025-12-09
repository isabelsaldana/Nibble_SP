// lib/pages/trash_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/recipe.dart';
import '../services/recipe_service.dart';
import 'view_recipe_page.dart';

class TrashPage extends StatelessWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
      ),
      body: StreamBuilder<List<Recipe>>(
        stream: RecipeService.deleted_recipes(uid),   // ✅ FIXED STREAM
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error loading trash: ${snap.error}'),
              ),
            );
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snap.data ?? [];

          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No deleted recipes.'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final r = items[index];
              final imageUrl =
                  r.imageUrls.isNotEmpty ? r.imageUrls.first : null;

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
                  leading: imageUrl == null
                      ? const CircleAvatar(
                          child: Icon(Icons.restaurant),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const CircleAvatar(
                              child: Icon(Icons.restaurant),
                            ),
                          ),
                        ),
                  title: Text(
                    r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text('Deleted recipe'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'restore') {
                        await RecipeService.restoreFromTrash(r.id);   // ✅ RESTORE
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Recipe restored'),
                            ),
                          );
                        }
                      } else if (v == 'delete_forever') {
                        final confirmed =
                            await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete forever?'),
                                    content: Text(
                                      'This will permanently delete "${r.title}". This cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;

                        if (!confirmed) return;

                        await RecipeService.deleteFromTrash(r.id); 
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Recipe permanently deleted'),
                            ),
                          );
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'restore',
                        child: Text('Restore'),
                      ),
                      PopupMenuItem(
                        value: 'delete_forever',
                        child: Text('Delete forever'),
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

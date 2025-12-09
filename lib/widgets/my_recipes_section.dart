// lib/widgets/my_recipes_section.dart
import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../pages/edit_recipe_page.dart';
import '../pages/view_recipe_page.dart';

class MyRecipesSection extends StatelessWidget {
  const MyRecipesSection({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final svc = RecipeService();

    return StreamBuilder<List<Recipe>>(
      stream: svc.userRecipes(uid),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error loading recipes: ${snap.error}'),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final items = snap.data ?? [];
        // 🔍 debug: see what Firestore is returning
        print('MyRecipesSection for uid=$uid -> ${items.length} recipes');

        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.menu_book,
                    size: 48, color: Colors.brown.shade300),
                const SizedBox(height: 12),
                const Text(
                  'No recipes yet.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap the "+" button below to add your first recipe.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // ---------- IG-style 3-column grid ----------
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,      // three per row
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1,    // square tiles
          ),
          itemBuilder: (context, index) {
            final r = items[index];
            final imageUrl =
                r.imageUrls.isNotEmpty ? r.imageUrls.first : null;

            return _RecipeGridTile(recipe: r, imageUrl: imageUrl);
          },
        );
      },
    );
  }
}

// ============= GRID TILE =============

class _RecipeGridTile extends StatefulWidget {
  const _RecipeGridTile({
    required this.recipe,
    required this.imageUrl,
  });

  final Recipe recipe;
  final String? imageUrl;

  @override
  State<_RecipeGridTile> createState() => _RecipeGridTileState();
}

class _RecipeGridTileState extends State<_RecipeGridTile> {
  double _scale = 1.0;

  void _setHover(bool hovering) {
    setState(() => _scale = hovering ? 1.02 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ViewRecipePage(recipe: widget.recipe),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ---------- Image with Hero ----------
                Positioned.fill(
                  child: Hero(
                    tag: 'recipe_${widget.recipe.id}',
                    child: widget.imageUrl == null
                        ? Container(
                            color: Colors.brown.shade100,
                            alignment: Alignment.center,
                            child: const Icon(Icons.restaurant, size: 28),
                          )
                        : Image.network(
                            widget.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.brown.shade100,
                              alignment: Alignment.center,
                              child:
                                  const Icon(Icons.restaurant, size: 28),
                            ),
                          ),
                  ),
                ),

                // ---------- Public / Private pill ----------
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.65),
                          Colors.black.withOpacity(0.35),
                        ],
                      ),
                    ),
                    child: Text(
                      widget.recipe.isPublic ? 'Public' : 'Private',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // ---------- 3-dot menu for Edit/Delete ----------
                Positioned(
                  right: 0,
                  top: 0,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    icon: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.more_vert,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    onSelected: (v) async {
                      if (v == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EditRecipePage(recipe: widget.recipe),
                          ),
                        );
                      } else if (v == 'delete') {
                        // confirm
                        final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete recipe?'),
                                content: Text(
                                  'Are you sure you want to delete "${widget.recipe.title}"?',
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

                        await RecipeService()
                            .deleteWithBackup(widget.recipe);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Recipe moved to trash'),
                            ),
                          );
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

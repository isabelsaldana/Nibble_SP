// lib/pages/view_recipe_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models/recipe.dart';
import 'services/saved_service.dart';
import 'pages/image_gallery_page.dart';

class ViewRecipePage extends StatefulWidget {
  const ViewRecipePage({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<ViewRecipePage> createState() => _ViewRecipePageState();
}

class _ViewRecipePageState extends State<ViewRecipePage> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _difficultyLabel(String? diff) {
    switch (diff) {
      case 'easy':
        return 'Easy';
      case 'medium':
        return 'Medium';
      case 'hard':
        return 'Hard';
      default:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final cs = Theme.of(context).colorScheme;

    final me = FirebaseAuth.instance.currentUser;
    final uid = me?.uid;
    final savedSvc = SavedService();

    final images = recipe.imageUrls;
    final hasImages = images.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          recipe.title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (uid != null)
            StreamBuilder<bool>(
              stream: savedSvc.isSavedStream(uid, recipe.id),
              builder: (context, snap) {
                final isSaved = snap.data ?? false;
                return IconButton(
                  tooltip: isSaved ? 'Remove from saved' : 'Save recipe',
                  icon: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                  ),
                  onPressed: () async {
                    await savedSvc.toggleSaved(uid: uid, recipe: recipe);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isSaved
                              ? 'Removed from saved'
                              : 'Saved to your recipes',
                        ),
                        duration: const Duration(milliseconds: 900),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------- IMAGE CAROUSEL ----------
            if (hasImages)
              Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ImageGalleryPage(
                            imageUrls: images,
                            initialIndex: _currentPage,
                            // 👇 hero tag matching the current image
                            heroTag: 'recipe_${recipe.id}_$_currentPage',
                          ),
                        ),
                      );
                    },
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: images.length,
                          onPageChanged: (i) {
                            setState(() => _currentPage = i);
                          },
                          itemBuilder: (context, index) {
                            final url = images[index];
                            return Hero(
                              // 👇 hero tag pattern that matches gallery heroTag
                              tag: 'recipe_${recipe.id}_$index',
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.brown.shade100,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                    size: 32,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Page indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < images.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin:
                              const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _currentPage ? 12 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _currentPage
                                ? cs.primary
                                : cs.primary.withOpacity(.25),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${images.length} photos · swipe to view',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.brown.shade400,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              )
            else
              const SizedBox(height: 12),

            // ---------- BODY CONTENT ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + public/private
                  Text(
                    recipe.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        recipe.isPublic
                            ? Icons.public
                            : Icons.lock_outline,
                        size: 16,
                        color: recipe.isPublic
                            ? cs.primary
                            : Colors.brown.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        recipe.isPublic
                            ? 'Public recipe'
                            : 'Private recipe',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.brown.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tags
                  if (recipe.tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: -4,
                      children: recipe.tags
                          .map(
                            (t) => Chip(
                              label: Text('#$t'),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Meta row: prep / cook / serves / difficulty
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          _MetaItem(
                            icon: Icons.timer_outlined,
                            label: 'Prep',
                            value: recipe.prepMinutes != null
                                ? '${recipe.prepMinutes} min'
                                : '—',
                          ),
                          _MetaItem(
                            icon: Icons.schedule_outlined,
                            label: 'Cook',
                            value: recipe.cookMinutes != null
                                ? '${recipe.cookMinutes} min'
                                : '—',
                          ),
                          _MetaItem(
                            icon: Icons.restaurant_outlined,
                            label: 'Serves',
                            value: recipe.servings != null
                                ? '${recipe.servings}'
                                : '—',
                          ),
                          _MetaItem(
                            icon: Icons.leaderboard_outlined,
                            label: 'Difficulty',
                            value: _difficultyLabel(recipe.difficulty),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  if (recipe.description != null &&
                      recipe.description!.trim().isNotEmpty) ...[
                    Text(
                      recipe.description!.trim(),
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Ingredients card
                  Text(
                    'Ingredients',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.brown.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final ing in recipe.ingredients)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text('• '),
                                  Expanded(
                                    child: Text(
                                      ing,
                                      style: const TextStyle(
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Steps card
                  Text(
                    'Steps',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.brown.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < recipe.steps.length; i++)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${i + 1}. ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      recipe.steps[i],
                                      style: const TextStyle(
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------- small widget for meta icons row ---------- */

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: cs.primary),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.brown.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

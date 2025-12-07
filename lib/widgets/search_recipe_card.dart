import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recipe.dart';
import '../pages/view_recipe_page.dart';

class SearchRecipeCard extends StatefulWidget {
  final Recipe recipe;
  const SearchRecipeCard({super.key, required this.recipe});

  @override
  State<SearchRecipeCard> createState() => _SearchRecipeCardState();
}

class _SearchRecipeCardState extends State<SearchRecipeCard> {
  bool _submitting = false;
  int _hoverRating = 0; // For hover/tap preview

  /// Add a new rating
  Future<void> _addRating(int rating) async {
    setState(() => _submitting = true);

    final docRef =
        FirebaseFirestore.instance.collection('recipes').doc(widget.recipe.id);

    try {
      // Append the new rating atomically
      await docRef.update({
        'ratings': FieldValue.arrayUnion([rating])
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit rating: $e')),
      );
    } finally {
      setState(() => _submitting = false);
      setState(() => _hoverRating = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        widget.recipe.imageUrls.isNotEmpty ? widget.recipe.imageUrls.first : null;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewRecipePage(recipe: widget.recipe),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            // IMAGE
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: imageUrl == null
                  ? Container(
                      width: 100,
                      height: 100,
                      color: Colors.brown.shade200,
                      child: const Icon(Icons.restaurant, size: 26),
                    )
                  : Image.network(
                      imageUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
            ),

            // TITLE + RATING
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.recipe.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // ⭐ Average rating from ratings list
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('recipes')
                          .doc(widget.recipe.id)
                          .snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const SizedBox(height: 18);
                        }

                        final data =
                            snap.data!.data() as Map<String, dynamic>?;

                        final List<int> ratings = data?['ratings'] != null
                            ? List<int>.from(data!['ratings'])
                            : [];

                        final avg = ratings.isNotEmpty
                            ? ratings.reduce((a, b) => a + b) / ratings.length
                            : 0.0;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  ratings.isEmpty
                                      ? 'No ratings yet'
                                      : 'Rating: ${avg.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                if (ratings.isNotEmpty)
                                  ...List.generate(5, (i) {
                                    return Icon(
                                      i < avg.round()
                                          ? Icons.star
                                          : Icons.star_border,
                                      size: 18,
                                      color: Colors.amber,
                                    );
                                  }),
                                if (ratings.isNotEmpty) const SizedBox(width: 6),
                                if (ratings.isNotEmpty)
                                  Text(
                                    '(${ratings.length})',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black54),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            // Rate this recipe (interactive stars)
                            Row(
                              children: [
                                const Text('Rate this recipe:'),
                                const SizedBox(width: 8),
                                for (int i = 1; i <= 5; i++)
                                  MouseRegion(
                                    onEnter: (_) {
                                      setState(() => _hoverRating = i);
                                    },
                                    onExit: (_) {
                                      setState(() => _hoverRating = 0);
                                    },
                                    child: IconButton(
                                      icon: Icon(
                                        i <= (_hoverRating > 0
                                                ? _hoverRating
                                                : 5)
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: Colors.amber,
                                      ),
                                      onPressed: _submitting
                                          ? null
                                          : () => _addRating(i),
                                    ),
                                  ),
                                if (_submitting)
                                  const SizedBox(
                                    width: 8,
                                  ),
                                if (_submitting)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

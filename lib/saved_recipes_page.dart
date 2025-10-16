import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SavedRecipesPage extends StatelessWidget {
  const SavedRecipesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Please log in to see saved recipes."));
    }

    final savedStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved')
        .snapshots();

    return StreamBuilder(
      stream: savedStream,
      builder: (context, savedSnapshot) {
        if (!savedSnapshot.hasData || savedSnapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No saved recipes yet."));
        }

        final savedIds = savedSnapshot.data!.docs.map((doc) => doc.id).toList();

        return StreamBuilder(
          stream: FirebaseFirestore.instance
              .collection('recipes')
              .where(FieldPath.documentId, whereIn: savedIds)
              .snapshots(),
          builder: (context, recipeSnapshot) {
            if (!recipeSnapshot.hasData || recipeSnapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No saved recipes found."));
            }

            final recipes = recipeSnapshot.data!.docs;

            return ListView.builder(
              itemCount: recipes.length,
              itemBuilder: (context, index) {
                final data = recipes[index].data();
                final ingredients = (data['ingredients'] as List?)?.join(', ') ?? '';
                final steps = data['steps'] ?? '';
                final tags = (data['tags'] as List?)?.join(', ') ?? '';

                return Card(
                  margin: const EdgeInsets.all(12),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data['imageUrl'] != null)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Image.network(
                            data['imageUrl'],
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['title'] ?? 'Untitled Recipe',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            if (tags.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  "Tags: $tags",
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text("Ingredients: $ingredients"),
                            const SizedBox(height: 8),
                            Text("Steps:\n$steps"),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

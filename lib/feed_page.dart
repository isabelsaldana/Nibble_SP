import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  Future<void> _toggleSave(String recipeId, bool isSaved) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final savedRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved');

    if (isSaved) {
      await savedRef.doc(recipeId).delete();
    } else {
      await savedRef.doc(recipeId).set({'recipeId': recipeId});
    }
  }

  Future<bool> _isRecipeSaved(String recipeId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('saved')
        .doc(recipeId)
        .get();

    return doc.exists;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('recipes')
          .where('isPublic', isEqualTo: true)
          .orderBy('localCreatedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No recipes yet — be the first to post! 🍳"));
        }

        final recipes = snapshot.data!.docs;

        return ListView.builder(
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final data = recipes[index].data();
            final recipeId = recipes[index].id;
            final ingredients = (data['ingredients'] as List?)?.join(', ') ?? '';
            final steps = data['steps'] ?? '';
            final tags = (data['tags'] as List?)?.join(', ') ?? '';

            return FutureBuilder<bool>(
              future: _isRecipeSaved(recipeId),
              builder: (context, savedSnapshot) {
                final isSaved = savedSnapshot.data ?? false;
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    data['title'] ?? 'Untitled Recipe',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isSaved ? Icons.bookmark : Icons.bookmark_outline,
                                    color: Colors.orangeAccent,
                                  ),
                                  onPressed: () => _toggleSave(recipeId, isSaved),
                                ),
                              ],
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
                            Text(
                              "Ingredients: $ingredients",
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Steps:\n$steps",
                              style: const TextStyle(fontSize: 14),
                            ),
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

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
            return Card(
              margin: const EdgeInsets.all(12),
              elevation: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data['imageUrl'] != null)
                    Image.network(data['imageUrl'], height: 200, width: double.infinity, fit: BoxFit.cover),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      data['title'] ?? 'Untitled Recipe',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(data['steps'] ?? ''),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

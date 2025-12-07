// lib/feed_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/recipe.dart';
import 'models/app_user.dart';
import 'services/recipe_service.dart';
import 'services/user_service.dart';
import 'pages/view_recipe_page.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});
  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('recipes')
            .where('isPublic', isEqualTo: true)
            .orderBy('localCreatedAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          final recipes = docs.map((d) => Recipe.fromFirestore(d)).toList();
          if (recipes.isEmpty) return const Center(child: Text('No public recipes yet'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: recipes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final r = recipes[i];
              return RecipeCard(
                recipe: r,
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => ViewRecipePage(recipe: r)));
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Small reusable card using image and detailed info, now with author details.
class RecipeCard extends StatelessWidget {
   RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
  });
  
  final Recipe recipe;
  final VoidCallback? onTap;

  final _userSvc =  UserService(); 

  @override
  Widget build(BuildContext context) {
    final imageUrl = recipe.imageUrls.isNotEmpty ? recipe.imageUrls.first : null;
    
    return InkWell(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Author Info (Fetched via FutureBuilder using recipe.authorId)
            FutureBuilder<AppUser?>(
              future: _userSvc.getUserProfile(recipe.authorId),
              builder: (context, snapshot) {
                final user = snapshot.data;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                    radius: 16,
                    child: user?.photoURL == null ? const Icon(Icons.person, size: 20) : null,
                  ),
                  title: Text(
                    user?.displayName ?? 'Loading...', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                  ),
                  subtitle: user?.username != null ? Text('@${user!.username}', style: const TextStyle(fontSize: 12)) : null,
                  onTap: () {
                    // TODO: Navigate to author profile
                  },
                );
              },
            ),

            // 2. Recipe Image
            if (imageUrl != null)
              SizedBox(
                height: 180,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return Center(child: CircularProgressIndicator(value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1) : null));
                    },
                    errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              )
            else
              SizedBox(
                height: 120,
                width: double.infinity,
                child: Center(
                  child: Text(recipe.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),

            // 3. Title and Rating
            Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 12.0),
              child: Row(
                children: [
                  Expanded(child: Text(recipe.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  // Compact Star Rating/Count (Fixed Overflow)
                  StreamBuilder<Map<String, dynamic>>(
                    stream: RecipeService().streamAverageRating(recipe.id),
                    builder: (context, snap) {
                      final data = snap.data ?? {'avg': 0.0, 'count': 0};
                      final avg = (data['avg'] as double?) ?? 0.0;
                      final count = (data['count'] as int?) ?? 0;
                      
                      return SizedBox(
                        width: 100, // Fixed width
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.star, size: 16, color: avg > 0 ? Colors.amber : Colors.grey.shade400),
                            const SizedBox(width: 2), 
                            Text(avg > 0 ? avg.toStringAsFixed(1) : '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), 
                            const SizedBox(width: 4), 
                            Text('($count)', style: const TextStyle(color: Colors.black54, fontSize: 11)),
                          ],
                        ),
                      );
                    },
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
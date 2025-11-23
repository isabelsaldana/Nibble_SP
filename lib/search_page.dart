// lib/search_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <--- NEW IMPORT
import 'package:flutter/material.dart';

import 'models/recipe.dart';
import 'pages/view_recipe_page.dart';
import 'pages/view_profile_page.dart'; // <--- NEW IMPORT

/// Helper: "2h ago", "3d ago", etc.
String _timeAgo(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final weeks = diff.inDays ~/ 7;
  return '${weeks}w ago';
}

// NEW: Define the search types
enum SearchType { recipes, users } 

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  String _query = '';
  SearchType _searchType = SearchType.recipes; // <--- NEW DEFAULT STATE

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _query = _controller.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _searchRecipes() {
    if (_query.length < 3) {
      return const Stream.empty();
    }
    // Search by title. Due to Firestore limitations, we search for titles starting with the query.
    return FirebaseFirestore.instance
        .collection('recipes')
        .where('isPublic', isEqualTo: true)
        .where('titleLower', isGreaterThanOrEqualTo: _query)
        .where('titleLower', isLessThanOrEqualTo: '$_query\uf8ff')
        .limit(50)
        .snapshots();
  }
  
  // NEW: Function to search users
  Stream<QuerySnapshot<Map<String, dynamic>>> _searchUsers() {
    if (_query.length < 3) {
      return const Stream.empty(); // Only search for queries of 3+ characters
    }
    final query = _query.toLowerCase();
    
    // Search by username. You could extend this to search displayName too.
    return FirebaseFirestore.instance
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query) 
        .where('username', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .snapshots();
  }


  // Helper widget to build the search bar in the AppBar
  PreferredSizeWidget _buildSearchBar() {
    final cs = Theme.of(context).colorScheme;

    return AppBar(
      automaticallyImplyLeading: false,
      title: TextField(
        controller: _controller,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: 'Search ${_searchType == SearchType.recipes ? 'recipes' : 'users'}',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide(
              color: cs.outline.withOpacity(.4),
            ),
          ),
          filled: true,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  // MODIFIED: _buildContent to handle both recipe and user results
  Widget _buildContent() {
    if (_query.length < 3) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Enter at least 3 characters to search for ${_searchType == SearchType.recipes ? 'recipes' : 'users'}.',
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    if (_searchType == SearchType.recipes) {
      // Existing Recipe Search Logic
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _searchRecipes(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data?.docs.map((d) => Recipe.fromFirestore(d)).toList() ?? [];

          if (items.isEmpty) {
            return Center(child: Text('No recipes found for "$_query"'));
          }
          
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _RecipeGridItem(recipe: items[index]);
            },
          );
        },
      );
    } else {
      // NEW: User Search Content
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _searchUsers(), // Uses the new user search stream
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          final me = FirebaseAuth.instance.currentUser;

          if (docs.isEmpty) {
            return Center(child: Text('No users found for "$_query"'));
          }
          
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data = docs[i].data();
              final uid = docs[i].id;
              final displayName = data['displayName'] as String? ?? '';
              final username = data['username'] as String? ?? '';
              
              // Do not show the current user in search results
              if (uid == me?.uid) return const SizedBox.shrink(); 

              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(displayName.isNotEmpty ? displayName : '@$username'),
                subtitle: Text(username.isNotEmpty ? '@$username' : 'No username'),
                onTap: () {
                  // Navigate to the user's profile page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ViewProfilePage(uid: uid),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildSearchBar(),
      body: Column(
        children: [
          // NEW: Tab Bar to switch between Recipes and Users
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Recipes'),
                  selected: _searchType == SearchType.recipes,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _searchType = SearchType.recipes);
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Users'),
                  selected: _searchType == SearchType.users,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _searchType = SearchType.users);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _buildContent(), // Calls the modified content builder
          ),
        ],
      ),
    );
  }
}

// ... (existing _RecipeGridItem class is here)

class _RecipeGridItem extends StatelessWidget {
  const _RecipeGridItem({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ViewRecipePage(recipe: recipe),
            ),
          );
        },
        child: Stack(
          children: [
            // Image
            if (recipe.imageUrls.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  recipe.imageUrls.first,
                  fit: BoxFit.cover,
                ),
              ),
            if (recipe.imageUrls.isEmpty)
              const Positioned.fill(
                child: Center(
                  child: Icon(Icons.restaurant_menu, size: 40),
                ),
              ),

            // Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Title + optional time
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (recipe.createdAt != null)
                    Text(
                      _timeAgo(recipe.createdAt),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
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
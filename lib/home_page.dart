// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'feed_page.dart';
import 'add_recipe_page.dart';
import 'saved_recipes_page.dart';
import 'my_profile_page.dart';
import 'search_page.dart';

class HomePage extends StatefulWidget {
  final int initialTab;
  final String? initialQuery;

  const HomePage({
    super.key,
    this.initialTab = 0,
    this.initialQuery,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab.clamp(0, 4);
  }

  @override
  Widget build(BuildContext context) {
    const brandBrown = Color(0xFF6B3E2E);

    final pages = [
      const FeedPage(),
      SearchPage(initialQuery: widget.initialQuery),
      AddRecipePage(
        onPosted: () {
          setState(() => _selectedIndex = 4);
        },
      ),
      const SavedRecipesPage(),
      MyProfilePage(), // ✅ MyProfilePage is not const in your project
    ];

    return Scaffold(
      appBar: _selectedIndex == 0
          ? AppBar(
              centerTitle: false,
              titleSpacing: 16,
              toolbarHeight: 68,
              elevation: 0,
              title: Text(
                'Nibble',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4,
                  color: brandBrown,
                ),
              ),
            )
          : null,
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Add',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border),
            activeIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

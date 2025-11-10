// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'login_page.dart';
import 'feed_page.dart';
import 'add_recipe_page.dart';
import 'saved_recipes_page.dart';
import 'profile_page.dart';
import 'search_page.dart'; // 👈 make sure this import is here

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // Pages for the bottom nav tabs
  late final List<Widget> _pages = [
    const FeedPage(),         // 0
    const SearchPage(),       // 1 👈 Search tab
    AddRecipePage(            // 2
      onPosted: () {
        // after posting, jump to Profile tab (index 4)
        setState(() {
          _selectedIndex = 4;
        });
      },
    ),
    SavedRecipesPage(),       // 3
    ProfilePage(),            // 4
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const brandBrown = Color(0xFF6B3E2E); // logo text color

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
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search', // 👈 new tab
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

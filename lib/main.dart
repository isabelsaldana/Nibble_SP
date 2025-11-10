// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'auth_gate.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'home_page.dart';
import 'onboarding_profile_flow.dart';
import 'profile_page.dart';
import 'profile_edit.dart';
import 'settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const NibbleApp());
}

class NibbleApp extends StatelessWidget {
  const NibbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ---- Desaturated brown palette (darker, with grey undertone) ----
    const brownDark = Color(0xFF5A4336);      // main accent: deep, slightly grey
    const brownMid = Color(0xFF7C5E4D);       // seed colour for scheme
    const brownLight = Color(0xFFB59986);     // soft accent
    const brownVeryLight = Color(0xFFF1E3D8); // page background

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nibble App',

      theme: ThemeData(
        useMaterial3: true,

        // Build Material palette from our mid brown
        colorScheme: ColorScheme.fromSeed(
          seedColor: brownMid,
          brightness: Brightness.light,
        ),

        // Warm but subtle background
        scaffoldBackgroundColor: brownVeryLight,

        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: brownVeryLight,
          foregroundColor: Colors.black87,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),

        // Cards used for recipes, ingredients, steps, etc.
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0.8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.zero,
        ),

        // Chips for tags, meta info, etc.
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          backgroundColor: brownLight.withOpacity(0.25),
          selectedColor: brownDark.withOpacity(0.18),
        ),

        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: brownDark,                 // dark bar (same as Edit profile)
          selectedItemColor: brownVeryLight,          // 👈 beige for active icon + label
          unselectedItemColor: brownLight,            // softer light brown for inactive
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedIconTheme: const IconThemeData(size: 26),
          unselectedIconTheme: const IconThemeData(size: 24),
        ),



        inputDecorationTheme: const InputDecorationTheme(
          border: UnderlineInputBorder(),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: brownDark,
              width: 1.5,
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: brownDark,
          ),
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: brownDark,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),

      home: const AuthGate(),

      routes: {
        '/login': (_) => const LoginPage(),
        '/signup': (_) => const SignUpPage(),
        '/home': (_) => const HomePage(),
        '/onboarding': (_) => const OnboardingProfileFlow(),
        '/profile': (_) => ProfilePage(),
        '/profile/edit': (_) => const ProfileEditPage(),
        '/settings': (_) => const SettingsPage(),
      },

      onUnknownRoute: (settings) =>
          MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }
}

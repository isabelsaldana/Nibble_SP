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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const NibbleApp());
}

class NibbleApp extends StatelessWidget {
  const NibbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nibble App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const AuthGate(), // <- AuthGate decides

      routes: {
        '/login'      : (_) => const LoginPage(),
        '/signup'     : (_) => const SignUpPage(),
        '/home'       : (_) => const HomePage(),
        '/onboarding' : (_) => const OnboardingProfileFlow(),
        '/profile'      : (_) => ProfilePage(),
        '/profile/edit' : (_) => const ProfileEditPage(),
        '/settings': (_) => const SettingsPage()

      },
        onUnknownRoute: (settings) =>
          MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }
}

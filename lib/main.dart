// Import Flutter's core UI framework
import 'package:flutter/material.dart';

// Import Firebase core package to initialize Firebase
import 'package:firebase_core/firebase_core.dart';

// Import the auto-generated Firebase configuration file
import 'firebase_options.dart';

// Import pages ive created
import 'login_page.dart';
import 'signup_page.dart';
import 'home_page.dart';

void main() async {
  // Ensure widgets and Firebase can initialize before running the app
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Start the app
  runApp(const NibbleApp());
}

// Root widget of the app
class NibbleApp extends StatelessWidget {
  const NibbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // App title
      title: 'Nibble App',

      // Theme of the app
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),

      // Start screen of the app
      home: const LoginPage(), // Shows LoginPage first
    );
  }
}

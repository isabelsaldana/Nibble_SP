// Import Flutter's core UI framework
import 'package:flutter/material.dart';

// Import Firebase core package to initialize Firebase
import 'package:firebase_core/firebase_core.dart';

// Import the auto-generated Firebase configuration file
import 'firebase_options.dart';

// Import pages I've created
import 'login_page.dart';
import 'signup_page.dart';
import 'home_page.dart';
import 'onboarding_profile_flow.dart';
import 'profile_page.dart';
import 'profile_edit.dart';

// Toggle Sign-Up preview at runtime (default = false, so Login stays first)
const bool kSignupPreview = bool.fromEnvironment('SIGNUP_PREVIEW');

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

      // Default behavior: show LoginPage first.
      // If you pass SIGNUP_PREVIEW=true at runtime, it will open SignUpPage instead.
      initialRoute: kSignupPreview ? '/signup' : '/login',
      routes: {
        '/login': (_) => const LoginPage(),
        '/signup': (_) => const SignUpPage(),
        '/home'  : (_) => const HomePage(),
        '/profile'      : (_) => ProfilePage(),      
        '/profile/edit' : (_) => const ProfileEditPage(),  
      },
    );
  }
}

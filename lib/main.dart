import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'auth_gate.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'home_page.dart';
import 'onboarding_profile_flow.dart';
import 'my_profile_page.dart';
import 'profile_edit.dart';
import 'settings_page.dart';
import 'theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
  );

  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
  );


  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const NibbleApp(),
    ),
  );
}

class NibbleApp extends StatelessWidget {
  const NibbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    const brownDark = Color(0xFF5A4336);
    const brownMid = Color(0xFF7C5E4D);
    const brownLight = Color(0xFFB59986);
    const brownVeryLight = Color(0xFFF1E3D8);

    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
          seedColor: brownMid, brightness: Brightness.light),
      scaffoldBackgroundColor: const Color.fromARGB(255, 247, 247, 247),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Color.fromARGB(255, 251, 251, 251),
        foregroundColor: Colors.black87,
        titleTextStyle: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0.8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),

        backgroundColor: brownLight.withOpacity(0.25),
        selectedColor: brownDark.withOpacity(0.18),

        // ✅ make chip text dark brown
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: brownDark,
        ),

        // optional: makes FilterChip checkmark match
        checkmarkColor: brownDark,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: brownDark,
        selectedItemColor: brownVeryLight,
        unselectedItemColor: brownLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedIconTheme: const IconThemeData(size: 26),
        unselectedIconTheme: const IconThemeData(size: 24),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: UnderlineInputBorder(),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: brownDark, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: brownDark)),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brownDark,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );

    final darkTheme = ThemeData.dark().copyWith(
      colorScheme: ColorScheme.dark(
        primary: brownMid,
        secondary: brownLight,
        surface: const Color(0xFF2A2A2A),
      ),
      scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2A2A2A),
        foregroundColor: Colors.white,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nibble App',
      theme: themeProvider.isDarkMode ? darkTheme : lightTheme,
      home: const AuthGate(),
      routes: {
        '/login': (_) => const LoginPage(),
        '/signup': (_) => const SignUpPage(),
        '/home': (_) => const HomePage(),
        '/onboarding': (_) => const OnboardingProfileFlow(),
        '/profile': (_) => MyProfilePage(),
        '/profile/edit': (_) => const ProfileEditPage(),
        '/settings': (_) => const SettingsPage(),
      },
      onUnknownRoute: (settings) =>
          MaterialPageRoute(builder: (_) => const AuthGate()),
    );
  }
}

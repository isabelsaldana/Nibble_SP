// lib/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_page.dart';
import 'home_page.dart';
import 'onboarding_profile_flow.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = authSnap.data;
        if (user == null) {
          return const LoginPage();
        }

        final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: docRef.snapshots(),
          builder: (context, docSnap) {
            if (docSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final exists = docSnap.data?.exists == true;
            final data = docSnap.data?.data() ?? {};

            final completed = data['onboardingComplete'] == true;
            final hasUsername = (data['username'] is String) && (data['username'] as String).isNotEmpty;

            if (completed) {
              return const HomePage();
            }

            // Safety net for older accounts: if they already have a username,
            // quietly mark onboarding as complete once and go Home.
            if (exists && hasUsername) {
              // Defer the write so we don't do side-effects during build.
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  await docRef.set({
                    'onboardingComplete': true,
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                } catch (_) {/* ignore */}
              });
              return const HomePage();
            }

            // Default: needs onboarding (either no doc, or doc without username & flag)
            return const OnboardingProfileFlow();
          },
        );
      },
    );
  }
}

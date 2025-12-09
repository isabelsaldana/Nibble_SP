import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pages/trash_page.dart';

import 'profile_edit.dart';
import 'widgets/my_recipes_section.dart'; // 👈 make sure this file exists

class ProfilePage extends StatelessWidget {
  ProfilePage({super.key});

  final _users = FirebaseFirestore.instance.collection('users');

  String _cacheBust(String url, int ver) =>
      url.contains('?') ? '$url&v=$ver' : '$url?v=$ver';

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _users.doc(me.uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snap.data!.data() ?? <String, dynamic>{};

        final displayName =
            (data['displayName'] as String?)?.trim().isNotEmpty == true
                ? (data['displayName'] as String).trim()
                : (me.displayName ?? 'Nibble user');

        final username =
            (data['username'] as String?)?.trim().isNotEmpty == true
                ? (data['username'] as String).trim()
                : (me.email != null ? me.email!.split('@').first : 'user');

        final bio = (data['bio'] as String?)?.trim() ?? '';

        String? photo = (data['photoURL'] as String?)?.trim();
        photo ??= me.photoURL;

        final updatedAtMs = (data['updatedAt'] is Timestamp)
            ? (data['updatedAt'] as Timestamp).millisecondsSinceEpoch
            : DateTime.now().millisecondsSinceEpoch;

        final bustedUrl =
            (photo != null && photo.isNotEmpty) ? _cacheBust(photo, updatedAtMs) : null;

        // debug
        // ignore: avoid_print
        print('ProfilePage photoURL => $photo  (busted => $bustedUrl)');

        return Scaffold(
          appBar: AppBar(
            title: const Text(''),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              // ---------- Header (no colored block, just padding) ----------
              SliverToBoxAdapter(
                child: _Header(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white.withOpacity(.9),
                        child: bustedUrl == null
                            ? _Initial(
                                displayName: displayName,
                                email: me.email,
                              )
                            : ClipOval(
                                child: Image.network(
                                  bustedUrl,
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, err, __) {
                                    // ignore: avoid_print
                                    print('Image.network error: $err');
                                    return _Initial(
                                      displayName: displayName,
                                      email: me.email,
                                    );
                                  },
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@$username',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ---------- Edit button ----------
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileEditPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit profile'),
                  ),
                ),
              ),

              // ---------- My Recipes header ----------
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'My Recipes',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // ---------- My Recipes list ----------
              SliverToBoxAdapter(
                child: MyRecipesSection(uid: me.uid),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ---------- helpers ---------- */

class _Header extends StatelessWidget {
  const _Header({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      color: bg, // 👈 same as the rest of the page, no block
      child: child,
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.displayName, required this.email});
  final String displayName;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final ch = displayName.isNotEmpty
        ? displayName[0]
        : (email?.isNotEmpty == true ? email![0] : 'N');
    return Text(
      ch.toUpperCase(),
      style: const TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }
}

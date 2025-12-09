// lib/profile_page.dart - UPDATED to display photoUrl

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pages/trash_page.dart';

import 'profile_edit.dart' as profile_edit;
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
                : (me.displayName?.trim().isNotEmpty == true
                    ? me.displayName!.trim()
                    : 'Your Profile');
        final username = data['username'] as String?;
        final bio = data['bio'] as String?;
        final followersCount = (data['followers'] as List?)?.length ?? 0;
        final followingCount = (data['following'] as List?)?.length ?? 0;
        final photoUrl = data['photoUrl'] as String?; // <--- NEW: Get photoUrl
        final ver = data['photoVersion'] as int? ?? 0;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                automaticallyImplyLeading: false,
                pinned: true,
                title: Text(displayName),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const profile_edit.ProfileEditorPage()),
                      );
                    },
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'trash') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const TrashPage()),
                        );
                      }
                      if (v == 'signout') {
                        FirebaseAuth.instance.signOut();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'trash',
                        child: Text('Trash'),
                      ),
                      PopupMenuItem(
                        value: 'signout',
                        child: Text('Sign out'),
                      ),
                    ],
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: _Header(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Picture or Initial - MODIFIED
                          photoUrl?.isNotEmpty == true
                              ? CircleAvatar(
                                  radius: 40,
                                  backgroundImage: NetworkImage(_cacheBust(photoUrl!, ver)),
                                )
                              : _Initial(displayName: displayName, email: me.email),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (username?.isNotEmpty == true)
                                  Text(
                                    '@$username',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Followers/Following
                      Row(
                        children: [
                          Text('$followersCount Followers'),
                          const SizedBox(width: 16),
                          Text('$followingCount Following'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (bio?.isNotEmpty == true)
                        Text(
                          bio!,
                          style: const TextStyle(fontSize: 14),
                        ),
                    ],
                  ),
                ),
              ),

              // ---------- Section Title ----------
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                child: MyRecipesSection(),
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
      color: bg,
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
    return CircleAvatar(
      radius: 40,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        ch.toUpperCase(),
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
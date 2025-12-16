import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'pages/follow_lists_page.dart';
import 'profile_edit.dart';
import 'widgets/my_recipes_section.dart';

class MyProfilePage extends StatelessWidget {
  MyProfilePage({super.key});

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
                ? data['displayName']
                : (me.displayName ?? 'Nibble user');

        final username =
            (data['username'] as String?)?.trim().isNotEmpty == true
                ? data['username']
                : (me.email != null ? me.email!.split('@').first : 'user');

        final bio = (data['bio'] as String?)?.trim() ?? '';

        String? photo = (data['photoURL'] as String?)?.trim();
        photo ??= me.photoURL;

        final updatedAtMs = (data['updatedAt'] is Timestamp)
            ? (data['updatedAt'] as Timestamp).millisecondsSinceEpoch
            : DateTime.now().millisecondsSinceEpoch;

        final bustedUrl = (photo != null && photo.isNotEmpty)
            ? _cacheBust(photo, updatedAtMs)
            : null;

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
              // ---------- HEADER ----------
              SliverToBoxAdapter(
                child: _Header(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white.withOpacity(.9),
                        child: bustedUrl == null
                            ? _Initial(displayName: displayName, email: me.email)
                            : ClipOval(
                                child: Image.network(
                                  bustedUrl,
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _Initial(
                                    displayName: displayName,
                                    email: me.email,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),

                      Text(
                        '@$username',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),

                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],

                      // ✅ Followers / Following row
                      const SizedBox(height: 12),
                      _MyConnectionsRow(uid: me.uid),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ---------- Edit PROFILE ----------
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileEditPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text("Edit profile"),
                  ),
                ),
              ),

              // ---------- MY RECIPES ----------
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "My Recipes",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),

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

/* ---------------------------------------------------------
   HEADER WIDGETS
--------------------------------------------------------- */

class _Header extends StatelessWidget {
  const _Header({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      color: Theme.of(context).scaffoldBackgroundColor,
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
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/* ---------------------------------------------------------
   FOLLOWERS / FOLLOWING COUNTS (tap opens FollowListsPage)
--------------------------------------------------------- */

class _MyConnectionsRow extends StatelessWidget {
  const _MyConnectionsRow({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    final followersStream = FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("followers")
        .snapshots();

    final followingStream = FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("following")
        .snapshots();

    Widget countButton({
      required Stream<QuerySnapshot> stream,
      required String label,
      required int tabIndex, // 0=Followers, 1=Following
    }) {
      return Expanded(
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FollowListsPage(
                  uid: uid,
                  initialIndex: tabIndex,
                  isOwner: true,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "$count",
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(color: Colors.brown.shade600),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        countButton(stream: followersStream, label: "Followers", tabIndex: 0),
        countButton(stream: followingStream, label: "Following", tabIndex: 1),
      ],
    );
  }
}

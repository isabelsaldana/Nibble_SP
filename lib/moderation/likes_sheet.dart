import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../public_profile_page.dart';

class LikesSheet {
  static Future<void> open(
    BuildContext context, {
    required String recipeId,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _LikesSheetBody(recipeId: recipeId),
    );
  }
}

class _LikesSheetBody extends StatelessWidget {
  final String recipeId;
  const _LikesSheetBody({required this.recipeId});

  @override
  Widget build(BuildContext context) {
    final likesStream = FirebaseFirestore.instance
        .collection('recipes')
        .doc(recipeId)
        .collection('likes')
        .snapshots();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.40,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.brown.withOpacity(0.25),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Likes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: likesStream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No likes yet',
                        style: TextStyle(color: Colors.brown.shade400),
                      ),
                    );
                  }

                  // doc.id is the userId (because you save likes as /likes/{userId})
                  final userIds = docs.map((d) => d.id).toList();

                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                    itemCount: userIds.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.brown.withOpacity(0.12)),
                    itemBuilder: (context, i) {
                      final uid = userIds[i];

                      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                        builder: (context, userSnap) {
                          final data = userSnap.data?.data() ?? {};
                          final username = (data['username'] ?? '').toString();
                          final displayName = (data['displayName'] ?? username).toString();

                          final photo = (data['photo'] ??
                                  data['photoUrl'] ??
                                  data['photoURL'] ??
                                  data['profilePhotoUrl'] ??
                                  data['avatarUrl'])
                              ?.toString()
                              .trim();

                          final hasPhoto = photo != null && photo.isNotEmpty;

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundImage: hasPhoto ? NetworkImage(photo!) : null,
                              child: !hasPhoto ? const Icon(Icons.person) : null,
                            ),
                            title: Text(
                              displayName.isEmpty ? 'User' : displayName,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: username.isEmpty
                                ? null
                                : Text(
                                    '@$username',
                                    style: TextStyle(color: Colors.brown.shade600),
                                  ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PublicProfilePage(uid: uid),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

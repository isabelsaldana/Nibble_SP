import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../public_profile_page.dart';

class FollowListsPage extends StatelessWidget {
  final String uid; // whose profile we’re viewing
  final int initialIndex; // 0 = Followers, 1 = Following
  final bool isOwner; // if true, show Remove/Unfollow buttons

  const FollowListsPage({
    super.key,
    required this.uid,
    this.initialIndex = 0,
    this.isOwner = false,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Connections'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Followers'),
              Tab(text: 'Following'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _UserList(
              ownerUid: uid,
              mode: _FollowMode.followers,
              showActions: isOwner,
            ),
            _UserList(
              ownerUid: uid,
              mode: _FollowMode.following,
              showActions: isOwner,
            ),
          ],
        ),
      ),
    );
  }
}

enum _FollowMode { followers, following }

class _UserList extends StatelessWidget {
  final String ownerUid;
  final _FollowMode mode;
  final bool showActions;

  const _UserList({
    required this.ownerUid,
    required this.mode,
    required this.showActions,
  });

  CollectionReference<Map<String, dynamic>> _col() {
    final base = FirebaseFirestore.instance.collection('users').doc(ownerUid);
    return base.collection(mode == _FollowMode.followers ? 'followers' : 'following');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _col().orderBy('followedAt', descending: true).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: ${snap.error}'),
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(mode == _FollowMode.followers ? 'No followers yet.' : 'Not following anyone yet.'),
          );
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final otherUid = docs[i].id;
            return _UserRow(
              ownerUid: ownerUid,
              otherUid: otherUid,
              mode: mode,
              showActions: showActions,
            );
          },
        );
      },
    );
  }
}

class _UserRow extends StatelessWidget {
  final String ownerUid;
  final String otherUid;
  final _FollowMode mode;
  final bool showActions;

  const _UserRow({
    required this.ownerUid,
    required this.otherUid,
    required this.mode,
    required this.showActions,
  });

  Future<Map<String, dynamic>?> _loadUser() async {
    final snap = await FirebaseFirestore.instance.collection('users').doc(otherUid).get();
    return snap.data();
  }

  String _pickName(Map<String, dynamic>? u) {
    final d = (u?['displayName'] ?? '').toString().trim();
    return d.isNotEmpty ? d : 'User';
  }

  String _pickUsername(Map<String, dynamic>? u) {
    final x = (u?['username'] ?? '').toString().trim();
    return x.isNotEmpty ? x : '';
  }

  String? _pickPhoto(Map<String, dynamic>? u) {
    final keys = ['photo', 'photoUrl', 'photoURL', 'profilePhotoUrl', 'profilePictureUrl', 'avatarUrl', 'avatar'];
    for (final k in keys) {
      final v = u?[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(confirmText),
              ),
            ],
          ),
        ) ??
        false;
    return ok;
  }

  Future<void> _removeFollower(BuildContext context) async {
    final batch = FirebaseFirestore.instance.batch();

    final a = FirebaseFirestore.instance
        .collection('users')
        .doc(ownerUid)
        .collection('followers')
        .doc(otherUid);

    final b = FirebaseFirestore.instance
        .collection('users')
        .doc(otherUid)
        .collection('following')
        .doc(ownerUid);

    batch.delete(a);
    batch.delete(b);

    await batch.commit();
  }

  Future<void> _unfollow(BuildContext context) async {
    final batch = FirebaseFirestore.instance.batch();

    final a = FirebaseFirestore.instance
        .collection('users')
        .doc(ownerUid)
        .collection('following')
        .doc(otherUid);

    final b = FirebaseFirestore.instance
        .collection('users')
        .doc(otherUid)
        .collection('followers')
        .doc(ownerUid);

    batch.delete(a);
    batch.delete(b);

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadUser(),
      builder: (context, snap) {
        final u = snap.data;
        final name = _pickName(u);
        final username = _pickUsername(u);
        final photo = _pickPhoto(u);

        final handle = username.isNotEmpty ? '@$username' : name;

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: (photo != null && (photo.startsWith('http://') || photo.startsWith('https://')))
                ? NetworkImage(photo)
                : null,
            child: (photo == null) ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U') : null,
          ),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: username.isEmpty ? null : Text('@$username'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PublicProfilePage(uid: otherUid)),
            );
          },
          trailing: !showActions
              ? null
              : (mode == _FollowMode.followers)
                  ? OutlinedButton(
                      onPressed: () async {
                        final ok = await _confirm(
                          context,
                          title: 'Remove follower?',
                          message: 'Are you sure you want to remove $handle from your followers?',
                          confirmText: 'Remove',
                        );
                        if (!ok) return;
                        await _removeFollower(context);
                      },
                      child: const Text('Remove'),
                    )
                  : OutlinedButton(
                      onPressed: () async {
                        final ok = await _confirm(
                          context,
                          title: 'Unfollow?',
                          message: 'Are you sure you want to unfollow $handle?',
                          confirmText: 'Unfollow',
                        );
                        if (!ok) return;
                        await _unfollow(context);
                      },
                      child: const Text('Unfollow'),
                    ),
        );
      },
    );
  }
}

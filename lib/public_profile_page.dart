import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PublicProfilePage extends StatelessWidget {
  final String uid;
  const PublicProfilePage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;

    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection("users").doc(uid).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data!.data() ?? {};
        final photo = user["photo"];
        final displayName = user["displayName"] ?? "Unknown";
        final username = user["username"] ?? "";
        final bio = user["bio"] ?? "";

        return Scaffold(
          appBar: AppBar(title: Text(displayName)),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage:
                      (photo != null && photo != "") ? NetworkImage(photo) : null,
                  child: (photo == null || photo == "")
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: Text(
                  displayName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),

              Center(
                child: Text(
                  "@$username",
                  style: TextStyle(color: Colors.brown.shade600),
                ),
              ),

              if (bio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    bio,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ⭐ FOLLOWER COUNT
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("users")
                    .doc(uid)
                    .collection("followers")
                    .snapshots(),
                builder: (context, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  return Center(
                    child: Text(
                      "$count follower${count == 1 ? '' : 's'}",
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // ⭐ Follow button (only if viewing someone else)
              if (me != null && me.uid != uid)
                _FollowButton(myUid: me.uid, viewedUid: uid),
            ],
          ),
        );
      },
    );
  }
}

class _FollowButton extends StatefulWidget {
  final String myUid;
  final String viewedUid;

  const _FollowButton({required this.myUid, required this.viewedUid});

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _following = false;

  @override
  void initState() {
    super.initState();
    _loadFollowState();
  }

  Future<void> _loadFollowState() async {
    try {
      final ref = FirebaseFirestore.instance
          .collection("users")
          .doc(widget.viewedUid)
          .collection("followers")
          .doc(widget.myUid);

      final snap = await ref.get();
      if (!mounted) return;

      setState(() => _following = snap.exists);
    } catch (e) {
      debugPrint("Follow state load error: $e");
    }
  }

  Future<void> _toggleFollow() async {
    final ref = FirebaseFirestore.instance
        .collection("users")
        .doc(widget.viewedUid)
        .collection("followers")
        .doc(widget.myUid);

    try {
      if (_following) {
        await ref.delete();
      } else {
        await ref.set({"followedAt": Timestamp.now()});
      }

      if (mounted) {
        setState(() => _following = !_following);
      }
    } catch (e) {
      debugPrint("Follow error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: _toggleFollow,
      child: Text(_following ? "Unfollow" : "Follow"),
    );
  }
}

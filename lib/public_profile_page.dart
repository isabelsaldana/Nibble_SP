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
        final followerCount = user["followerCount"] ?? 0;
        final followingCount = user["followingCount"] ?? 0;

        return Scaffold(
          appBar: AppBar(title: Text(displayName)),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ------------------ PHOTO ------------------
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

              // ------------------ NAME ------------------
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

              const SizedBox(height: 12),

              // ------------------ COUNTS ------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Followers count
                  Column(
                    children: [
                      Text(
                        followerCount.toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "Followers",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),

                  const SizedBox(width: 28),

                  // Following count
                  Column(
                    children: [
                      Text(
                        followingCount.toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "Following",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
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

              const SizedBox(height: 24),

              // ------------------ FOLLOW BUTTON ------------------
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
    final myUid = widget.myUid;
    final viewedUid = widget.viewedUid;

    final followerRef = FirebaseFirestore.instance
        .collection("users")
        .doc(viewedUid)
        .collection("followers")
        .doc(myUid);

    final followingRef = FirebaseFirestore.instance
        .collection("users")
        .doc(myUid)
        .collection("following")
        .doc(viewedUid);

    if (_following) {
      // ---------------- UNFOLLOW ----------------
      await followerRef.delete();
      await followingRef.delete();

      FirebaseFirestore.instance.collection("users").doc(viewedUid).update({
        "followerCount": FieldValue.increment(-1),
      });

      FirebaseFirestore.instance.collection("users").doc(myUid).update({
        "followingCount": FieldValue.increment(-1),
      });
    } else {
      // ---------------- FOLLOW ----------------
      await followerRef.set({"followedAt": Timestamp.now()});
      await followingRef.set({"followedAt": Timestamp.now()});

      FirebaseFirestore.instance.collection("users").doc(viewedUid).update({
        "followerCount": FieldValue.increment(1),
      });

      FirebaseFirestore.instance.collection("users").doc(myUid).update({
        "followingCount": FieldValue.increment(1),
      });
    }

    if (mounted) {
      setState(() => _following = !_following);
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

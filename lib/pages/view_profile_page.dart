// lib/pages/view_profile_page.dart - CORRECTED

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ViewProfilePage extends StatefulWidget {
  final String uid;
  const ViewProfilePage({super.key, required this.uid});

  @override
  State<ViewProfilePage> createState() => _ViewProfilePageState();
}

class _ViewProfilePageState extends State<ViewProfilePage> {
  final _users = FirebaseFirestore.instance.collection('users');
  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;
  
  // We remove _isFollowing state here, and calculate it from the Stream's data in the build method.

  // Logic to add/remove the follow relationship in Firestore
  Future<void> _toggleFollow(bool currentlyFollowing) async {
    if (_currentUid == null || widget.uid == _currentUid) return;
    
    final meRef = _users.doc(_currentUid);
    final targetRef = _users.doc(widget.uid);
    
    try {
      if (currentlyFollowing) {
        // Unfollow
        await meRef.update({'following': FieldValue.arrayRemove([widget.uid])});
        await targetRef.update({'followers': FieldValue.arrayRemove([_currentUid])});
      } else {
        // Follow
        await meRef.update({'following': FieldValue.arrayUnion([widget.uid])});
        await targetRef.update({'followers': FieldValue.arrayUnion([_currentUid])});
      }
      // Note: Since we are using a StreamBuilder, the UI (including follower count and button text) 
      // will update automatically when Firestore confirms the change.
    } catch (e) {
      // Handle error
    }
  }

  // Helper to build a profile avatar (used by both this page and FeedPage)
  Widget _buildAvatar(String? photoUrl) {
    if (photoUrl?.isNotEmpty == true) {
      return CircleAvatar(
        radius: 36,
        backgroundImage: NetworkImage(photoUrl!),
      );
    }
    return const CircleAvatar(
      radius: 36,
      child: Icon(Icons.person, size: 40),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Stream 1: Fetches the target user's data
    final targetUserStream = _users.doc(widget.uid).snapshots();
    // Stream 2: Fetches the current user's data to determine follow status
    final currentUserStream = _users.doc(_currentUid).snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: targetUserStream,
      builder: (context, targetSnap) {
        if (!targetSnap.hasData || targetSnap.data!.data() == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final data = targetSnap.data!.data()!;
        final displayName = data['displayName'] as String? ?? 'User';
        final username = data['username'] as String? ?? 'N/A';
        final followers = (data['followers'] as List<dynamic>?)?.cast<String>() ?? [];
        final followersCount = followers.length;
        final photoUrl = data['photoUrl'] as String?; // <--- NEW: Profile Picture URL
        final isMyProfile = widget.uid == _currentUid;
        
        return Scaffold(
          appBar: AppBar(title: Text(displayName)),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildAvatar(photoUrl), // <--- NEW: Display Profile Picture
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          Text('@$username', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                        ],
                      ),
                      const Spacer(),
                      
                      if (!isMyProfile) // Only show the button if it's not the user's own profile
                        // StreamBuilder nested here to reactively update the Follow button
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: currentUserStream,
                          builder: (context, meSnap) {
                            if (!meSnap.hasData) return const SizedBox.shrink();

                            final meData = meSnap.data!.data() ?? {};
                            final meFollowing = (meData['following'] as List<dynamic>?)?.cast<String>() ?? [];
                            final isFollowing = meFollowing.contains(widget.uid);
                            
                            return ElevatedButton(
                              onPressed: () => _toggleFollow(isFollowing),
                              child: Text(isFollowing ? 'Unfollow' : 'Follow'),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Followers: $followersCount'), // This is reactive via the targetUserStream
                  const Divider(height: 32),
                  // Recipes section for this user could be added here
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
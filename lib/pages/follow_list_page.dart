import 'package:flutter/material.dart';
import 'follow_lists_page.dart';

class FollowListPage extends StatelessWidget {
  final String uid;
  final int initialTab;
  final bool isOwner;

  const FollowListPage({
    super.key,
    required this.uid,
    this.initialTab = 0,
    this.isOwner = false,
  });

  @override
  Widget build(BuildContext context) {
    return FollowListsPage(
      uid: uid,
      initialIndex: initialTab,
      isOwner: isOwner,
    );
  }
}

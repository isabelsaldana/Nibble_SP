// lib/services/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Map<String, dynamic>? _normalizeUser(
      String id, Map<String, dynamic>? raw) {
    if (raw == null) return null;

    final photo = (raw["photo"] ??
            raw["photoURL"] ??
            raw["photoUrl"] ??
            raw["profilePicture"])
        ?.toString();

    final username = raw["username"]?.toString();
    final usernameLower =
        raw["usernameLower"]?.toString() ?? username?.toLowerCase();

    return {
      "id": id,
      ...raw,
      if (photo != null && photo.isNotEmpty) "photo": photo,
      if (usernameLower != null) "usernameLower": usernameLower,
    };
  }

  static Stream<List<Map<String, dynamic>>> searchUsers(String query) {
    query = query.trim().toLowerCase();
    if (query.isEmpty) return Stream.value([]);

    return _db.collection("users").snapshots().map((snap) {
      return snap.docs
          .map((d) => _normalizeUser(d.id, d.data()))
          .whereType<Map<String, dynamic>>()
          .where((user) {
        final username = (user["usernameLower"] ?? "").toLowerCase();
        final display = (user["displayName"] ?? "").toLowerCase();

        return username.contains(query) || display.contains(query);
      }).toList();
    });
  }
}

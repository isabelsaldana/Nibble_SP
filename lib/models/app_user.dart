class AppUser {
  final String id;
  final String username;
  final String email;
  final String? displayName;
  final String? photoURL;

  AppUser({
    required this.id,
    required this.username,
    required this.email,
    this.displayName,
    this.photoURL,
  });

  factory AppUser.fromFirestore(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      displayName: data['displayName'] as String?,
      photoURL: data['photoURL'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
    };
  }
}

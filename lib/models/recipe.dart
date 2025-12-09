import 'package:cloud_firestore/cloud_firestore.dart';

class Recipe {
  final String id;
  final String authorId;
  final String title;
  final String? description;

  final List<String> ingredients;
  final List<String> ingredientsLower;

  final List<String> steps;

  final List<String> tags;
  final List<String> tagsLower;

  final List<String> imageUrls;
  final bool isPublic;

  final int? prepMinutes;
  final int? cookMinutes;
  final int? servings;
  final String? difficulty;

  final double averageRating;
  final int ratingCount;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  Recipe({
    required this.id,
    required this.authorId,
    required this.title,
    this.description,
    required this.ingredients,
    required this.ingredientsLower,
    required this.steps,
    required this.tags,
    required this.tagsLower,
    required this.imageUrls,
    required this.isPublic,
    this.prepMinutes,
    this.cookMinutes,
    this.servings,
    this.difficulty,
    this.averageRating = 0,
    this.ratingCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// Correct fromDoc()
  factory Recipe.fromDoc(DocumentSnapshot doc) {
    final raw = doc.data() as Map<String, dynamic>? ?? {};

    List<String> safeList(dynamic val) {
      if (val is Iterable) {
        return val.map((e) => e.toString()).toList();
      }
      return [];
    }

    return Recipe(
      id: doc.id,
      authorId: raw['authorId'] ?? "",
      title: raw['title'] ?? "",
      description: raw['description'] ?? "",
      ingredients: safeList(raw['ingredients']),
      ingredientsLower: safeList(raw['ingredientsLower']),
      steps: safeList(raw['steps']),
      tags: safeList(raw['tags']),
      tagsLower: safeList(raw['tagsLower']),
      imageUrls: safeList(raw['imageUrls']),
      isPublic: raw['isPublic'] ?? true,
      prepMinutes: raw['prepMinutes'],
      cookMinutes: raw['cookMinutes'],
      servings: raw['servings'],
      difficulty: raw['difficulty'],
      averageRating: (raw['averageRating'] ?? 0).toDouble(),
      ratingCount: (raw['ratingCount'] ?? 0).toInt(),
      createdAt: raw['createdAt'] is Timestamp
          ? (raw['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: raw['updatedAt'] is Timestamp
          ? (raw['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// ⭐ Correct alias so FeedPage/SearchPage works
  factory Recipe.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Recipe.fromDoc(doc);
  }

  Map<String, dynamic> toMap() {
    return {
      "authorId": authorId,
      "title": title,
      "titleLower": title.toLowerCase().trim(),
      "description": description,
      "ingredients": ingredients,
      "ingredientsLower": ingredientsLower,
      "steps": steps,
      "tags": tags,
      "tagsLower": tagsLower,
      "imageUrls": imageUrls,
      "isPublic": isPublic,
      "prepMinutes": prepMinutes,
      "cookMinutes": cookMinutes,
      "servings": servings,
      "difficulty": difficulty,
      "averageRating": averageRating,
      "ratingCount": ratingCount,
      "createdAt": createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    };
  }
}

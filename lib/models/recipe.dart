// lib/models/recipe.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Recipe {
  final String id;
  final String authorId;
  final String title;
  final String? description;
  final List<String> ingredients;
  final List<String> steps;
  final bool isPublic;
  final List<String> imageUrls;

  // ---- new metadata ----
  final int? prepMinutes;
  final int? cookMinutes;
  final int? servings;
  final String? difficulty; // 'easy', 'medium', 'hard'
  final List<String> tags;

  // ---- timestamps ----
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Recipe({
    required this.id,
    required this.authorId,
    required this.title,
    this.description,
    required this.ingredients,
    required this.steps,
    required this.isPublic,
    required this.imageUrls,
    this.prepMinutes,
    this.cookMinutes,
    this.servings,
    this.difficulty,
    this.tags = const [],
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'title': title,
      'description': description,
      'ingredients': ingredients,
      'steps': steps,
      'isPublic': isPublic,
      'imageUrls': imageUrls,
      // metadata
      'prepMinutes': prepMinutes,
      'cookMinutes': cookMinutes,
      'servings': servings,
      'difficulty': difficulty,
      'tags': tags,
      // createdAt/updatedAt set in RecipeService
    };
  }

  factory Recipe.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    // ----- ingredients: list OR legacy string -----
    final ingredientsRaw = data['ingredients'];
    List<String> ingredients;
    if (ingredientsRaw is List) {
      ingredients = ingredientsRaw.map((e) => e.toString()).toList();
    } else if (ingredientsRaw is String) {
      ingredients = ingredientsRaw
          .split(RegExp(r'[,\n]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else {
      ingredients = [];
    }

    // ----- steps: list OR legacy string -----
    final stepsRaw = data['steps'];
    List<String> steps;
    if (stepsRaw is List) {
      steps = stepsRaw.map((e) => e.toString()).toList();
    } else if (stepsRaw is String) {
      steps = stepsRaw
          .split(RegExp(r'[.\n]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else {
      steps = [];
    }

    // ----- image urls: new imageUrls[] OR old imageUrl -----
    List<String> imageUrls;
    if (data['imageUrls'] is List) {
      imageUrls =
          (data['imageUrls'] as List).map((e) => e.toString()).toList();
    } else if (data['imageUrl'] != null) {
      imageUrls = [data['imageUrl'].toString()];
    } else {
      imageUrls = [];
    }

    // ----- metadata -----
    int? _toInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : null);

    final prepMinutes = _toInt(data['prepMinutes']);
    final cookMinutes = _toInt(data['cookMinutes']);
    final servings = _toInt(data['servings']);

    final difficulty =
        data['difficulty'] != null ? data['difficulty'].toString() : null;

    List<String> tags = [];
    if (data['tags'] is List) {
      tags = (data['tags'] as List).map((e) => e.toString()).toList();
    }

    DateTime? createdAt;
    DateTime? updatedAt;
    final rawCreatedAt = data['createdAt'];
    final rawUpdatedAt = data['updatedAt'];
    if (rawCreatedAt is Timestamp) createdAt = rawCreatedAt.toDate();
    if (rawUpdatedAt is Timestamp) updatedAt = rawUpdatedAt.toDate();

    return Recipe(
      id: doc.id,
      authorId: (data['authorId'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      description: data['description']?.toString(),
      ingredients: ingredients,
      steps: steps,
      isPublic: data['isPublic'] == false ? false : true,
      imageUrls: imageUrls,
      prepMinutes: prepMinutes,
      cookMinutes: cookMinutes,
      servings: servings,
      difficulty: difficulty,
      tags: tags,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

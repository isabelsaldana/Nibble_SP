// lib/utils/search_index.dart
class SearchIndex {
  static List<String> buildRecipeIndex({
    required String title,
    String? description,
    List<dynamic>? tags,
    List<dynamic>? ingredients,
    dynamic steps, // can be List or String depending on your model
  }) {
    final tokens = <String>{};

    void addText(String? s) {
      if (s == null) return;
      final cleaned =
          s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').trim();
      if (cleaned.isEmpty) return;

      for (final w in cleaned.split(RegExp(r'\s+'))) {
        if (w.length < 2) continue;
        tokens.add(w);
      }

      // also add a "no spaces" version for phrases like "air fryer" -> "airfryer"
      final noSpace = cleaned.replaceAll(' ', '');
      if (noSpace.length >= 3) tokens.add(noSpace);
    }

    addText(title);
    addText(description);

    if (tags != null) {
      for (final t in tags) {
        if (t is String) addText(t);
      }
    }

    if (ingredients != null) {
      for (final ing in ingredients) {
        if (ing is String) {
          addText(ing);
        } else if (ing is Map) {
          // support flexible ingredient formats if you ever store maps
          final name = ing['name'] ?? ing['ingredient'] ?? ing['text'];
          if (name is String) addText(name);
        }
      }
    }

    if (steps is String) {
      addText(steps);
    } else if (steps is List) {
      for (final s in steps) {
        if (s is String) addText(s);
      }
    }

    // build prefixes so partial search works ("mil" finds "milk")
    final index = <String>{};
    for (final t in tokens) {
      final max = t.length > 15 ? 15 : t.length;
      for (int i = 2; i <= max; i++) {
        index.add(t.substring(0, i));
      }
    }

    return index.toList();
  }
}

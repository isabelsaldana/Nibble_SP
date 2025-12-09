import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models/recipe.dart';
import 'services/recipe_service.dart';
import 'services/storage_service.dart';

class AddRecipePage extends StatefulWidget {
  const AddRecipePage({super.key, this.onPosted});

  final VoidCallback? onPosted;

  @override
  State<AddRecipePage> createState() => _AddRecipePageState();
}

class _AddRecipePageState extends State<AddRecipePage> {
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _desc = TextEditingController();

  final _prepMinutes = TextEditingController();
  final _cookMinutes = TextEditingController();
  final _servings = TextEditingController();

  // dynamic ingredients & steps
  final List<TextEditingController> _ingredientCtrls = [
    TextEditingController(),
  ];
  final List<TextEditingController> _stepCtrls = [
    TextEditingController(),
  ];

  // tags
  final _tagInput = TextEditingController();
  final Set<String> _tags = {};

  String _difficulty = 'easy';

  // images: cover + extras
  Uint8List? _coverBytes;
  final List<Uint8List> _extraImages = [];
  static const int _maxImages = 15;

  bool _isPublic = true;
  bool _saving = false;

  final _svc = RecipeService();
  final _store = StorageService();
  late String _uid; // set in initState

  @override
  void initState() {
    super.initState();
    final me = FirebaseAuth.instance.currentUser;
    _uid = me?.uid ?? 'anonymous';
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _prepMinutes.dispose();
    _cookMinutes.dispose();
    _servings.dispose();
    _tagInput.dispose();

    for (final c in _ingredientCtrls) {
      c.dispose();
    }
    for (final c in _stepCtrls) {
      c.dispose();
    }

    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      // max total images = _maxImages (1 cover + extras)
      if (_coverBytes != null && _extraImages.length >= _maxImages - 1) {
        _showSnack('You can add up to $_maxImages photos per recipe.');
        return;
      }

      final x = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        if (_coverBytes == null) {
          _coverBytes = bytes; // first selected becomes cover
        } else {
          _extraImages.add(bytes);
        }
      });
    } catch (e) {
      _showSnack('Could not pick image: $e');
    }
  }

  bool _looksLowQualityText(String s, {int minLen = 3}) {
    final t = s.trim();
    if (t.length < minLen) return true;
    final letters = RegExp(r'[A-Za-z]').allMatches(t).length;
    if (letters < 2) return true;
    return false;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  int? _parseInt(String s) {
    s = s.trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_uid == 'anonymous') {
      _showSnack('You must be signed in to post a recipe.');
      return;
    }

    // collect ingredients & steps from dynamic fields
    final ings = _ingredientCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final stps = _stepCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (ings.length < 2) {
      _showSnack('Add at least 2 ingredients.');
      return;
    }
    if (stps.length < 2) {
      _showSnack('Add at least 2 steps.');
      return;
    }
    if (ings.any((i) => _looksLowQualityText(i, minLen: 3))) {
      _showSnack('Some ingredients look too short. Use clearer names.');
      return;
    }
    if (stps.any((s) => _looksLowQualityText(s, minLen: 5))) {
      _showSnack('Some steps are too short. Add a bit more detail.');
      return;
    }

    final prep = _parseInt(_prepMinutes.text);
    final cook = _parseInt(_cookMinutes.text);
    final servings = _parseInt(_servings.text);

    if (_isPublic) {
      if (_coverBytes == null) {
        _showSnack(
            'Public recipes should have a cover photo. Please add an image.');
        return;
      }
      if (_looksLowQualityText(_desc.text, minLen: 20)) {
        _showSnack('For public recipes, add a more detailed description.');
        return;
      }
      if (prep == null && cook == null) {
        _showSnack('For public recipes, please include prep or cook time.');
        return;
      }
      if (servings == null || servings <= 0) {
        _showSnack('For public recipes, please add servings.');
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final recipe = Recipe(
        id: 'tmp',
        authorId: _uid,
        title: _title.text.trim(),
        description:
            _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        ingredients: ings,
        ingredientsLower: ings.map((i) => i.toLowerCase()).toList(),  
        steps: stps,
        isPublic: _isPublic,
        imageUrls: const [], // will update after uploads
        prepMinutes: prep,
        cookMinutes: cook,
        servings: servings,
        difficulty: _difficulty,
        tags: _tags.toList(),
        tagsLower: _tags.map((t) => t.toLowerCase()).toList(),
      );

      final id = await _svc.create(recipe, _uid);

      // upload cover + extra images
      final imageUrls = <String>[];

      if (_coverBytes != null) {
        final coverUrl = await _store.uploadBytes(
          bytes: _coverBytes!,
          path: 'recipes/$_uid/${id}_cover.jpg',
        );
        imageUrls.add(coverUrl);
      }

      for (int i = 0; i < _extraImages.length; i++) {
        final url = await _store.uploadBytes(
          bytes: _extraImages[i],
          path: 'recipes/$_uid/${id}_extra_$i.jpg',
        );
        imageUrls.add(url);
      }

      if (imageUrls.isNotEmpty) {
        await _svc.update(id, {'imageUrls': imageUrls});
      }

      if (!mounted) return;
      _showSnack('Recipe posted!');
      widget.onPosted?.call();
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration get _in => const InputDecoration(
        border: UnderlineInputBorder(),
        labelStyle: TextStyle(fontWeight: FontWeight.w600),
      );

  // ---------- prettier sections ----------

  Widget _buildIngredientsSection() {
    return Card(
      elevation: 0,
      color: Colors.brown.shade50.withOpacity(0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ingredients',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() {
                            _ingredientCtrls.add(TextEditingController());
                          });
                        },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ingredient'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Column(
              children: [
                for (int i = 0; i < _ingredientCtrls.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 20,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.circle,
                            size: 6,
                            color: Colors.brown,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _ingredientCtrls[i],
                            decoration: _in.copyWith(
                              labelText: 'Ingredient ${i + 1}',
                            ),
                          ),
                        ),
                        if (_ingredientCtrls.length > 1)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _saving
                                ? null
                                : () {
                                    setState(() {
                                      final c =
                                          _ingredientCtrls.removeAt(i);
                                      c.dispose();
                                    });
                                  },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsSection() {
    return Card(
      elevation: 0,
      color: Colors.brown.shade50.withOpacity(0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Steps',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() {
                            _stepCtrls.add(TextEditingController());
                          });
                        },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Step'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Column(
              children: [
                for (int i = 0; i < _stepCtrls.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.brown.shade300,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _stepCtrls[i],
                            decoration: _in.copyWith(
                              labelText: 'Step ${i + 1}',
                            ),
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                          ),
                        ),
                        if (_stepCtrls.length > 1)
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _saving
                                ? null
                                : () {
                                    setState(() {
                                      final c = _stepCtrls.removeAt(i);
                                      c.dispose();
                                    });
                                  },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Recipe')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- Images: cover + gallery ----
            GestureDetector(
              onTap: _saving ? null : _pickImage,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Photos',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: cs.primary.withOpacity(
                          _coverBytes == null ? .3 : 0,
                        ),
                      ),
                    ),
                    child: _coverBytes == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.camera_alt_outlined,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isPublic
                                      ? 'Add a nice cover photo (required for public)'
                                      : 'Add a cover photo (optional)',
                                  style: TextStyle(
                                    color: Colors.brown.shade400,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(
                              _coverBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  if (_extraImages.isNotEmpty)
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _extraImages.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(10),
                                child: Image.memory(
                                  _extraImages[index],
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: InkWell(
                                  onTap: _saving
                                      ? null
                                      : () {
                                          setState(() {
                                            _extraImages
                                                .removeAt(index);
                                          });
                                        },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black
                                          .withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    padding:
                                        const EdgeInsets.all(2),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Add photos of the finished dish, ingredients, and steps (up to $_maxImages).',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.brown.shade400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ---- Title ----
            TextFormField(
              controller: _title,
              decoration: _in.copyWith(labelText: 'Recipe Title'),
              textInputAction: TextInputAction.next,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.length < 3) {
                  return 'Title should be at least 3 characters';
                }
                if (t.length > 80) {
                  return 'Title is a bit long (max 80 chars)';
                }
                if (_looksLowQualityText(t, minLen: 3)) {
                  return 'Please use a more descriptive title';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),

            // ---- Description ----
            TextFormField(
              controller: _desc,
              decoration: _in.copyWith(
                labelText: 'Description',
                helperText:
                    'Describe the dish, flavor, or special tips.',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // ---- prep/cook/servings/difficulty ----
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _prepMinutes,
                    keyboardType: TextInputType.number,
                    decoration:
                        _in.copyWith(labelText: 'Prep (min)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cookMinutes,
                    keyboardType: TextInputType.number,
                    decoration:
                        _in.copyWith(labelText: 'Cook (min)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _servings,
                    keyboardType: TextInputType.number,
                    decoration:
                        _in.copyWith(labelText: 'Servings'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _difficulty,
                    decoration:
                        _in.copyWith(labelText: 'Difficulty'),
                    items: const [
                      DropdownMenuItem(
                          value: 'easy', child: Text('Easy')),
                      DropdownMenuItem(
                          value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(
                          value: 'hard', child: Text('Hard')),
                    ],
                    onChanged: (v) =>
                        setState(() => _difficulty = v ?? 'easy'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ---- Tags (user-generated) ----
            Text(
              'Tags',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagInput,
                    decoration: _in.copyWith(
                      labelText: 'Add a tag',
                      helperText:
                          'Type and press enter (e.g. "spicy", "meal prep")',
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (value) {
                      final t = value.trim().toLowerCase();
                      if (t.isEmpty) return;
                      setState(() {
                        _tags.add(
                          t.startsWith('#') ? t.substring(1) : t,
                        );
                        _tagInput.clear();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final t = _tagInput.text.trim().toLowerCase();
                    if (t.isEmpty) return;
                    setState(() {
                      _tags.add(
                        t.startsWith('#') ? t.substring(1) : t,
                      );
                      _tagInput.clear();
                    });
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: -6,
              children: [
                for (final tag in _tags)
                  Chip(
                    label: Text('#$tag'),
                    onDeleted: () {
                      setState(() => _tags.remove(tag));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ---- Ingredients (card) ----
            _buildIngredientsSection(),
            const SizedBox(height: 16),

            // ---- Steps (card) ----
            _buildStepsSection(),
            const SizedBox(height: 12),

            // ---- Public / private ----
            SwitchListTile(
              value: _isPublic,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _isPublic = v),
              title: const Text('Public recipe'),
              subtitle: Text(
                _isPublic
                    ? 'Shared on the feed. Needs a good photo & details.'
                    : 'Only visible to you on your profile.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),

            // ---- Submit ----
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.upload),
              label: const Text('Post Recipe'),
            ),
          ],
        ),
      ),
    );
  }
}

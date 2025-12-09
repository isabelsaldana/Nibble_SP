import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../services/storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditRecipePage extends StatefulWidget {
  const EditRecipePage({super.key, required this.recipe});
  final Recipe recipe;

  @override
  State<EditRecipePage> createState() => _EditRecipePageState();
}

class _EditRecipePageState extends State<EditRecipePage> {
  late TextEditingController _title;
  late TextEditingController _desc;
  late TextEditingController _ingredients;
  late TextEditingController _steps;
  bool _isPublic = true;
  Uint8List? _newImage;
  bool _saving = false;

  final _svc = RecipeService();
  final _store = StorageService();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    _title = TextEditingController(text: r.title);
    _desc = TextEditingController(text: r.description ?? '');
    _ingredients = TextEditingController(text: r.ingredients.join(', '));
    _steps = TextEditingController(text: r.steps.join('\n'));
    _isPublic = r.isPublic;
  }

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;
    _newImage = await x.readAsBytes();
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final ings = _ingredients.text.split(',').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList();
      final stps = _steps.text.split('\n').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList();

      final updates = {
        'title': _title.text.trim(),
        'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        'ingredients': ings,
        'ingredientsLower': ings.map((e) => e.toLowerCase()).toList(), 
        'steps': stps,
         'tags': widget.recipe.tags,        
        'isPublic': _isPublic,
      };

      if (_newImage != null) {
        final url = await _store.uploadBytes(
          bytes: _newImage!, path: 'recipes/$_uid/${widget.recipe.id}.jpg');
        updates['imageUrls'] = [url];
      }

      await _svc.update(widget.recipe.id, updates);
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final currentImg = _newImage;
    final url = (r.imageUrls.isNotEmpty) ? r.imageUrls.first : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Recipe')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _pick,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.brown.shade100.withOpacity(.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: currentImg != null
                ? ClipRRect(borderRadius: BorderRadius.circular(12),
                    child: Image.memory(currentImg, fit: BoxFit.cover))
                : (url == null)
                    ? const Center(child: Text('Tap to add image 📷'))
                    : ClipRRect(borderRadius: BorderRadius.circular(12),
                        child: Image.network(url, fit: BoxFit.cover)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Recipe Title')),
          const SizedBox(height: 8),
          TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 8),
          TextField(controller: _ingredients, decoration: const InputDecoration(labelText: 'Ingredients (comma-separated)')),
          const SizedBox(height: 8),
          TextField(controller: _steps, decoration: const InputDecoration(labelText: 'Steps (one per line)'), maxLines: 6),
          const SizedBox(height: 8),
          SwitchListTile(value: _isPublic, onChanged: (v)=>setState(()=>_isPublic=v), title: const Text('Public recipe')),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.save),
            label: const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}

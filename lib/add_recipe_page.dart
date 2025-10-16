import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AddRecipePage extends StatefulWidget {
  const AddRecipePage({super.key});

  @override
  State<AddRecipePage> createState() => _AddRecipePageState();
}

class _AddRecipePageState extends State<AddRecipePage> {
  final _titleController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _stepsController = TextEditingController();
  final _tagsController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<void> _uploadRecipe() async {
    if (_titleController.text.isEmpty ||
        _ingredientsController.text.isEmpty ||
        _stepsController.text.isEmpty ||
        _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields and pick an image.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // Upload image to Firebase Storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref =
          FirebaseStorage.instance.ref().child('recipe_images/$fileName');
      await ref.putFile(_imageFile!);
      final imageUrl = await ref.getDownloadURL();

      // Prepare data for Firestore
      final ingredients = _ingredientsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final tags = _tagsController.text
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();

      // Save recipe data in Firestore
      await FirebaseFirestore.instance.collection('recipes').add({
        'userId': user.uid,
        'title': _titleController.text.trim(),
        'ingredients': ingredients,
        'steps': _stepsController.text.trim(),
        'tags': tags,
        'imageUrl': imageUrl,
        'isPublic': true,
        'createdAt': FieldValue.serverTimestamp(),
        'localCreatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Recipe posted successfully!")),
      );

      // Clear fields
      _titleController.clear();
      _ingredientsController.clear();
      _stepsController.clear();
      _tagsController.clear();
      setState(() => _imageFile = null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Recipe"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                  image: _imageFile != null
                      ? DecorationImage(
                          image: FileImage(_imageFile!), fit: BoxFit.cover)
                      : null,
                ),
                child: _imageFile == null
                    ? const Center(child: Text("Tap to add image 📷"))
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Recipe Title"),
            ),
            TextField(
              controller: _ingredientsController,
              decoration: const InputDecoration(
                  labelText: "Ingredients (comma-separated)"),
              maxLines: 2,
            ),
            TextField(
              controller: _stepsController,
              decoration: const InputDecoration(labelText: "Steps"),
              maxLines: 4,
            ),
            TextField(
              controller: _tagsController,
              decoration:
                  const InputDecoration(labelText: "Tags (comma-separated)"),
              maxLines: 1,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _uploadRecipe,
                    icon: const Icon(Icons.upload),
                    label: const Text("Post Recipe"),
                  ),
          ],
        ),
      ),
    );
  }
}

// lib/add_recipe_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';

class AddRecipePage extends StatefulWidget {
  const AddRecipePage({super.key});

  @override
  State<AddRecipePage> createState() => _AddRecipePageState();
}

class _AddRecipePageState extends State<AddRecipePage> {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final ingredientsCtrl = TextEditingController();
  final tagsCtrl = TextEditingController();
  final stepsCtrl = TextEditingController();
  final imageCtrl = TextEditingController(); // single URL or multiple separated by commas

  bool isPublic = true;

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final recipe = Recipe(
      id: "",
      authorId: uid,
      title: titleCtrl.text.trim(),
      description: descCtrl.text.trim(),
      ingredients: ingredientsCtrl.text.split("\n").map((e) => e.trim()).toList(),
      ingredientsLower: ingredientsCtrl.text.toLowerCase().split("\n").map((e) => e.trim()).toList(),
      steps: stepsCtrl.text.split("\n").map((e) => e.trim()).toList(),
      tags: tagsCtrl.text.split(" ").map((e) => e.trim()).toList(),
      tagsLower: tagsCtrl.text.toLowerCase().split(" ").map((e) => e.trim()).toList(),
      imageUrls: imageCtrl.text.split(",").map((e) => e.trim()).toList(),
      isPublic: isPublic,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await FirebaseFirestore.instance.collection("recipes").add(recipe.toMap());

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Recipe")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Title")),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description")),
          TextField(controller: ingredientsCtrl, decoration: const InputDecoration(labelText: "Ingredients (one per line)"), maxLines: 4),
          TextField(controller: stepsCtrl, decoration: const InputDecoration(labelText: "Steps (one per line)"), maxLines: 4),
          TextField(controller: tagsCtrl, decoration: const InputDecoration(labelText: "Tags (#burger #easy)")),
          TextField(controller: imageCtrl, decoration: const InputDecoration(labelText: "Image URLs (comma separated)")),
          
          SwitchListTile(
            title: const Text("Public Recipe"),
            value: isPublic,
            onChanged: (v) => setState(() => isPublic = v),
          ),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submit,
            child: const Text("Post Recipe"),
          )
        ],
      ),
    );
  }
}

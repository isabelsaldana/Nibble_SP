import 'package:flutter/material.dart';

class SavedRecipesPage extends StatelessWidget {
  const SavedRecipesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Recipes"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: Text("Your saved recipes will appear here 🔖"),
      ),
    );
  }
}

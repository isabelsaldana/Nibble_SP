import 'package:flutter/material.dart';

class AddRecipePage extends StatelessWidget {
  const AddRecipePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add New Recipe"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const TextField(
              decoration: InputDecoration(labelText: "Recipe Title"),
            ),
            const TextField(
              decoration: InputDecoration(labelText: "Ingredients (comma-separated)"),
              maxLines: 2,
            ),
            const TextField(
              decoration: InputDecoration(labelText: "Steps"),
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: connect to RecipeService().addRecipe(...)
              },
              icon: const Icon(Icons.upload),
              label: const Text("Post Recipe"),
            ),
          ],
        ),
      ),
    );
  }
}

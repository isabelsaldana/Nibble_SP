import 'package:flutter/material.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Later: load public recipes from Firestore
    return ListView.builder(
      itemCount: 5, // dummy for now
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text("ChefUser${index + 1}"),
                subtitle: const Text("2 hrs ago"),
              ),
              Container(
                height: 200,
                color: Colors.grey[300],
                child: const Center(child: Text("Recipe Image Placeholder")),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  "Delicious Recipe #${index + 1}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text("This recipe includes fresh ingredients and simple steps."),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.bookmark_border), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.comment_outlined), onPressed: () {}),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }
}

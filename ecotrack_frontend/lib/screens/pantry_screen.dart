import 'package:flutter/material.dart';

class PantryScreen extends StatelessWidget {
  const PantryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🛒 Digital Pantry Inventory',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Bar Widget
            TextField(
              decoration: InputDecoration(
                hintText: 'Search pantry...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 20),

            // Main Inventory List
            Expanded(
              child: ListView(
                children: [
                  _buildPantryItem(
                    '🥑 Avocados',
                    '3 units remaining',
                    'Expires in 3 days',
                    Colors.green,
                  ),
                  _buildPantryItem(
                    '🍞 Whole Wheat Bread',
                    '1 loaf',
                    'Expires today!',
                    Colors.orange,
                  ),
                  _buildPantryItem(
                    '🥦 Fresh Broccoli',
                    '500g',
                    'Expires in 6 days',
                    Colors.green,
                  ),
                  _buildPantryItem(
                    '🥩 Chicken Breast',
                    '2 packs',
                    'Expired 1 day ago 🗑️',
                    Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // A helper function to build list items cleanly without duplicating code!
  Widget _buildPantryItem(
    String name,
    String quantity,
    String details,
    Color statusColor,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text('$quantity • $details'),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(Icons.fastfood, color: statusColor),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.check_circle_outline, color: Colors.grey),
          onPressed: () {
            // Future feature: Mark item as consumed!
          },
        ),
      ),
    );
  }
}

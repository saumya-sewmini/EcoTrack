import 'package:flutter/material.dart';
import '../services/api_service.dart'; // Import our network bridge!

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  late Future<List<dynamic>> _pantryItems;

  @override
  void initState() {
    super.initState();
    // When this screen loads, instantly hit the Python server for fresh data!
    _pantryItems = ApiService.fetchPantryItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🛒 Live Python Pantry',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'This data is being pulled directly from your running Python API backend!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 15),

            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _pantryItems,
                builder: (context, snapshot) {
                  // While waiting for Python to respond, show a loading wheel
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // If something went wrong, show an error message
                  else if (snapshot.hasError ||
                      snapshot.data == null ||
                      snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text(
                        '❌ Could not connect to Python backend server. Make sure uvicorn is running!',
                      ),
                    );
                  }

                  // Once data arrives safely, build the list dynamically!
                  final items = snapshot.data!;
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text(
                            item['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Text(
                            'Quantity: ${item['quantity']} • Expires in ${item['days_left']} days',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          leading: const CircleAvatar(
                            backgroundColor: Colors.greenAccent,
                            child: Icon(Icons.bolt, color: Colors.green),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

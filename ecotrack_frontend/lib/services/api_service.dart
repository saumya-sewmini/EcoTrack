import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Since we are running the Flutter app on Chrome, 'localhost:8000' targets our Python server perfectly!
  static const String baseUrl = 'http://localhost:8000/api';

  // Function to fetch the pantry items from our Python server
  static Future<List<dynamic>> fetchPantryItems() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/pantry'));

      if (response.statusCode == 200) {
        // Decode the raw JSON response text into a readable Dart list
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load pantry data from server');
      }
    } catch (e) {
      print("Network Error: $e");
      return [];
    }
  }
}

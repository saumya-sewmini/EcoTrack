import 'dart:convert';
import 'package:flutter/material.dart';
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

  // Add this function inside your ApiService class
  static Future<Map<String, dynamic>?> uploadAndScanImage(
    dynamic pickedFile,
  ) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/scan'));

      // Read the file bytes out of the picker (works beautifully across mobile and web!)
      var bytes = await pickedFile.readAsBytes();
      var multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: pickedFile.name,
      );

      request.files.add(multipartFile);

      // Send the request over the network to Python
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Upload Error: $e");
      return null;
    }
  }

  // Fetch an AI generated recipe based on what is in the pantry database
  static Future<String> fetchAIChefRecipe() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/recipes'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['recipe'] ?? "No recipe text returned.";
      }
      return "Failed to communicate with the kitchen server.";
    } catch (e) {
      return "Error contacting backend: $e";
    }
  }

  // Send a DELETE request to clear an item out of the backend array
  static Future deletePantryItem(int id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/pantry/$id'));
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error deleting item: $e");
      return false;
    }
  }
}

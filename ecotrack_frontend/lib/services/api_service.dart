import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ApiService {
  /// Base endpoint configuration targeting the local Python application environment.
  static const String _baseUrl = 'http://localhost:8000/api';

  /// Fetches the collective pantry data records from the cloud repository service.
  /// Returns an empty list upon caught infrastructure exceptions.
  static Future<List<dynamic>> fetchPantryItems() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/pantry'));

      if (response.statusCode == 200) {
        final List<dynamic> parsedPayload = jsonDecode(response.body);
        return parsedPayload;
      } else {
        throw Exception(
          'Server returned non-OK status: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint("ApiService [fetchPantryItems] Error: $e");
      return [];
    }
  }

  /// Dispatches a multipart POST binary network payload stream to the
  /// computer vision edge engine for real-time model extraction parsing.
  static Future<Map<String, dynamic>?> uploadAndScanImage(
    XFile pickedFile,
  ) async {
    try {
      final Uri targetUri = Uri.parse('$_baseUrl/scan');
      final http.MultipartRequest request = http.MultipartRequest(
        'POST',
        targetUri,
      );

      // Extracts the raw texture array bytes out of the platform-agnostic file abstraction
      final List<int> byteData = await pickedFile.readAsBytes();
      final http.MultipartFile multipartFile = http.MultipartFile.fromBytes(
        'file',
        byteData,
        filename: pickedFile.name,
      );

      request.files.add(multipartFile);

      // Stream evaluation workflow for capturing server transmission frames
      final http.StreamedResponse streamedResponse = await request.send();
      final http.Response response = await http.Response.fromStream(
        streamedResponse,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> successPayload = jsonDecode(response.body);
        return successPayload;
      }

      debugPrint(
        "ApiService [uploadAndScanImage] Failed with status code: ${response.statusCode}",
      );
      return null;
    } catch (e) {
      debugPrint("ApiService [uploadAndScanImage] Pipeline Exception: $e");
      return null;
    }
  }

  /// Recommends dynamic dish blueprints based on current data constraints via
  /// the backend processing engine.
  static Future<String> fetchAIChefRecipe() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/recipes'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> dynamicBody = jsonDecode(response.body);
        return dynamicBody['recipe'] ??
            "No prescriptive text was returned by the engine.";
      }
      return "Backend communications anomaly: Internal server failure.";
    } catch (e) {
      debugPrint("ApiService [fetchAIChefRecipe] Connection Interrupted: $e");
      return "Network transaction breakdown: Backend system unreachable.";
    }
  }

  /// Dispatches an isolated DELETE method to terminate an entry within the data matrix by its unique ID.
  static Future<bool> deletePantryItem(int id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/pantry/$id'));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint(
        "ApiService [deletePantryItem] Exception on node sequence destruction: $e",
      );
      return false;
    }
  }
}

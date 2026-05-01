import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class LocationService {
  Future<Map<String, dynamic>> getBusLocation() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/location/bus-location');

    // Get token from storage
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your internet connection.');
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData['data'];
      } else {
        final message = responseData['message'] ?? 'Failed to get bus location: ${response.statusCode}';
        throw Exception(message);
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
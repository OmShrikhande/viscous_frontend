import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/login_response.dart';
import 'api_config.dart';

class AuthService {
  Future<LoginResponse> login(String phone) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone': phone,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your internet connection and try again.');
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return LoginResponse.fromJson(responseData);
      } else {
        final message =
            responseData['message'] ?? 'Login failed: ${response.statusCode}';
        throw Exception(message);
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

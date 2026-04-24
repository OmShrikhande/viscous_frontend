import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/login_response.dart';

class AuthService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';

  Future<LoginResponse> login(String mobile, String password) async {
    final url = Uri.parse('$baseUrl/api/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'mobile': mobile,
          'password': password,
        },
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

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
<<<<<<< HEAD
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'email': email, 'password': password},
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception(
                'Connection timeout. Please check your internet connection and try again.',
              );
            },
          );
=======
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
>>>>>>> c1c5301a202ae6e6c351a186241b8a4d4ef7b395

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

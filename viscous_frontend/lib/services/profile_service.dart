import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/login_response.dart';
import 'api_config.dart';
import 'storage_service.dart';

class ProfileService {
  final StorageService _storage = StorageService();

  Future<User> getMyProfile() async {
    final token = await _storage.getToken();
    if (token == null) throw Exception('Missing auth token');

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/users/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final json = jsonDecode(response.body);
    if (response.statusCode != 200 || json['success'] != true) {
      throw Exception(json['message'] ?? 'Failed to load profile');
    }
    return User.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<User> updateMyProfile({
    required String name,
    required String email,
    required String phone,
    required String userstop,
    Map<String, dynamic>? notificationPreferences,
    Map<String, dynamic>? notificationQuietHours,
  }) async {
    final token = await _storage.getToken();
    if (token == null) throw Exception('Missing auth token');

    final requestBody = <String, dynamic>{
      'name': name,
      'email': email,
      'phone': phone,
      'userstop': userstop,
    };
    if (notificationPreferences != null) {
      requestBody['notificationPreferences'] = notificationPreferences;
    }
    if (notificationQuietHours != null) {
      requestBody['notificationQuietHours'] = notificationQuietHours;
    }

    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/users/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    final json = jsonDecode(response.body);
    if (response.statusCode != 200 || json['success'] != true) {
      throw Exception(json['message'] ?? 'Failed to update profile');
    }

    final user = User.fromJson(json['data'] as Map<String, dynamic>);
    await _storage.updateStoredUser(user);
    return user;
  }
}

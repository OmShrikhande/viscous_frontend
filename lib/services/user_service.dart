import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'storage_service.dart';

class UserService {
  final StorageService _storageService = StorageService();

  Future<void> upsertFcmToken(String fcmToken) async {
    final token = await _storageService.getToken();
    if (token == null || token.isEmpty) return;

    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/users/me/fcm-token');
    final response = await http.patch(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'fcmToken': fcmToken}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to register FCM token');
    }
  }
}

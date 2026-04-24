import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/login_response.dart';

class StorageService {
  static const String _tokenKey = 'auth_token';
  static const String _loginDataKey = 'login_data';

  Future<void> saveLoginData(LoginResponse loginResponse) async {
    final prefs = await SharedPreferences.getInstance();
    if (loginResponse.token != null) {
      await prefs.setString(_tokenKey, loginResponse.token!);
    }
    await prefs.setString(_loginDataKey, jsonEncode(loginResponse.toJson()));
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<LoginResponse?> getLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    final loginDataString = prefs.getString(_loginDataKey);
    if (loginDataString != null) {
      final loginDataJson = jsonDecode(loginDataString);
      return LoginResponse.fromJson(loginDataJson);
    }
    return null;
  }

  Future<void> clearLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_loginDataKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}

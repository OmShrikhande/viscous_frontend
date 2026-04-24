import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/login_response.dart';

class StorageService {
  static const String _tokenKey = 'auth_token';
  static const String _loginDataKey = 'login_data';
  static const String _isDarkKey = 'is_dark_mode';

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
<<<<<<< HEAD
}
=======

  Future<void> setDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isDarkKey, isDark);
  }

  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isDarkKey) ?? true; // Default to dark mode
  }
}
>>>>>>> c1c5301a202ae6e6c351a186241b8a4d4ef7b395

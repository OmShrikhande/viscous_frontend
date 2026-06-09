import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl {
    final envUrl = dotenv.env['BASE_URL'];
    
    if (kIsWeb) {
      // If we're on the web and the configured URL is the Android emulator default,
      // override it to localhost so Chrome can connect to the backend.
      if (envUrl != null && envUrl.contains('10.0.2.2')) {
        return 'http://localhost:3000';
      }
      return envUrl ?? 'http://localhost:3000';
    }
    
    // If we're on Android and the configured URL points to localhost or 127.0.0.1,
    // map it to 10.0.2.2 so the emulator can connect to the host's backend.
    if (Platform.isAndroid && envUrl != null) {
      if (envUrl.contains('localhost')) {
        return envUrl.replaceAll('localhost', '10.0.2.2');
      }
      if (envUrl.contains('127.0.0.1')) {
        return envUrl.replaceAll('127.0.0.1', '10.0.2.2');
      }
    }
    
    return envUrl ?? 'http://10.0.2.2:3000';
  }
}

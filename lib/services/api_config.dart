import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl {
    final envUrl = dotenv.env['BASE_URL'];
    
    // If we're on the web and the configured URL is the Android emulator default,
    // override it to localhost so Chrome can connect to the backend.
    if (kIsWeb && envUrl != null && envUrl.contains('10.0.2.2')) {
      return 'http://localhost:3000';
    }
    
    return envUrl ?? 'http://10.0.2.2:3000';
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/route_response.dart';
import 'api_config.dart';

class ApiService {
  Future<RouteResponse> getRoute(String routeNumber) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/route/$routeNumber');
    print('API_SERVICE: Fetching route from $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        print('API_SERVICE: Successfully fetched route data');
        return RouteResponse.fromJson(responseData['data']);
      } else {
        print('API_SERVICE: Error response: ${response.body}');
        throw Exception(responseData['error'] ?? 'Failed to fetch route');
      }
    } catch (e) {
      print('API_SERVICE: Exception: $e');
      throw Exception('Network error: $e');
    }
  }
}

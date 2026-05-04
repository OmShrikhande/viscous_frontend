import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/route_response.dart';
import 'api_config.dart';

class ApiService {
  Future<RouteResponse> getRoute(String routeNumber) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/route/$routeNumber');
    debugPrint('[ApiService] Fetching route: $url');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && responseData['success'] == true) {
        debugPrint('[ApiService] Route data fetched successfully.');
        return RouteResponse.fromJson(responseData['data'] as Map<String, dynamic>);
      } else {
        debugPrint('[ApiService] Error response: ${response.statusCode}');
        throw Exception(responseData['error'] ?? 'Failed to fetch route');
      }
    } on Exception catch (e) {
      debugPrint('[ApiService] Exception: $e');
      rethrow;
    }
  }
}

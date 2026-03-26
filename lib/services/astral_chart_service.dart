import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class AstralChartService {
  final String _baseUrl = "https://windowsdemeter.com/api";
  final AuthService _authService = AuthService();

  // Helper method for headers matching auth_service.dart structure
  Future<Map<String, String>> _getHeaders() async {
    String? token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // GET /api/user/charts
  Future<List<dynamic>> getUserCharts() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user/charts'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? data; // Adjust based on your API response wrapper
      }
      return [];
    } catch (e) {
      print("Error fetching user charts: $e");
      return [];
    }
  }

  // POST /api/user/charts
  Future<Map<String, dynamic>> createChart({
    required String title,
    required String birthDate,
    required String birthTime,
    required double birthLat,
    required double birthLon,
    required String timezone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/user/charts'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'titulo': title,
          'birth_date': birthDate,
          'birth_time': birthTime,
          'birth_lat': birthLat,
          'birth_lon': birthLon,
          'timezone': timezone,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al crear la carta astral',
          'errors': data['errors']
        };
      }
    } catch (e) {
      print("Error creating astral chart: $e");
      return {'success': false, 'message': 'Excepción: $e'};
    }
  }
}

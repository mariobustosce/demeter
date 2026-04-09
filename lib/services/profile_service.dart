import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/referral_payload.dart';
import '../models/user.dart';
import 'api_config.dart';
import 'auth_service.dart';

class ProfileService {
  final String _baseUrl = ApiConfig.baseUrl;
  final AuthService _authService = AuthService();

  // Helper para headers
  Future<Map<String, String>> _getHeaders() async {
    String? token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _unwrapBody(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return body;
  }

  String _readErrorMessage(Map<String, dynamic> body, String fallback) {
    if (body['message'] != null) {
      return body['message'].toString();
    }

    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) {
        return first.first.toString();
      }
    }

    return fallback;
  }

  Future<User?> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user/profile'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final userData = _unwrapBody(data);
        return User.fromJson(userData);
      }
      return null;
    } catch (e) {
      print("Error obteniendo perfil: $e");
      return null;
    }
  }

  Future<ReferralPayload?> getReferralPayload() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user/referral'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ReferralPayload.fromJson(_unwrapBody(data));
      }
      return null;
    } catch (e) {
      print('Error obteniendo referido: $e');
      return null;
    }
  }

  Future<bool> updateProfile(String name, String email) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/user/profile'),
        headers: await _getHeaders(),
        body: jsonEncode({'name': name, 'email': email}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error actualizando perfil: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> updatePassword(
    String currentPassword,
    String newPassword,
    String confirmPassword,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/user/profile/password'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': confirmPassword,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Contraseña actualizada',
        };
      }

      return {
        'success': false,
        'message': _readErrorMessage(data, 'Error desconocido'),
      };
    } catch (e) {
      print("Error actualizando contraseña: $e");
      return {'success': false, 'message': 'Error de conexión'};
    }
  }

  Future<bool> deleteAccount(String password) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/user/profile'),
        headers: await _getHeaders(),
        body: jsonEncode({'password': password}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error eliminando cuenta: $e");
      return false;
    }
  }
}

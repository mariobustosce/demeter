import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class OracleService {
  final String _baseUrl = "https://windowsdemeter.com/api"; 
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> consultarAlOraculo({
    required String pregunta,
    required String nivelContexto,
    required bool usaCartaAstral,
    String? cartaAstralId,
    Map<String, dynamic>? contextoCompleto,
  }) async {
    final token = await _authService.getToken();
    final url = Uri.parse('$_baseUrl/oraculo/consultar');

    final payload = {
      "pregunta": pregunta,
      "nivel_contexto": nivelContexto, // 'basico', 'intermedio', 'premium'
      "usa_carta_astral": usaCartaAstral,
      "carta_astral_id": usaCartaAstral ? cartaAstralId : null,
      "contexto_completo": contextoCompleto ?? {},
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'response': responseData['response'],
          'nuevoBalance': responseData['nuevo_balance'],
        };
      } else if (response.statusCode == 403 && responseData['insufficient_coins'] == true) {
        return {
          'success': false,
          'error': 'Polvo estelar insuficiente',
          'details': 'Necesitas ${responseData['required_coins']} y tienes ${responseData['current_balance']}.'
        };
      } else if (response.statusCode == 422) {
        return {
          'success': false,
          'error': 'Error de validación',
          'details': responseData['errors'].toString(),
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Error desconocido',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión',
        'details': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> consultarCompatibilidad({
    required String cartaAId,
    required String cartaBId,
    String nivelContexto = 'intermedio',
  }) async {
    final token = await _authService.getToken();
    final url = Uri.parse('$_baseUrl/oraculo/compatibilidad');

    final payload = {
      "carta_a_id": cartaAId,
      "carta_b_id": cartaBId,
      "nivel_contexto": nivelContexto,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      debugPrint("DEBUG COMPATIBILIDAD CODE: ${response.statusCode}");
      debugPrint("DEBUG COMPATIBILIDAD BODY: ${response.body}");

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'texto': responseData['texto'] ?? responseData['response'],
          'nuevoBalance': responseData['nuevo_balance'],
        };
      } else if (response.statusCode == 403 && responseData['insufficient_coins'] == true) {
        return {
          'success': false,
          'error': 'Polvo estelar insuficiente',
          'details': 'Necesitas ${responseData['required_coins']} y tienes ${responseData['current_balance']}.'
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Error desconocido',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error de conexión',
        'details': e.toString(),
      };
    }
  }

  Future<List<dynamic>> getHistorialConsultas() async {
    final token = await _authService.getToken();
    final url = Uri.parse('$_baseUrl/user/history');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded;
        } else if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data') && decoded['data'] is List) {
            return decoded['data'] as List<dynamic>;
          } else if (decoded.containsKey('data') && decoded['data'] is Map && decoded['data'].containsKey('data') && decoded['data']['data'] is List) {
           return decoded['data']['data'] as List<dynamic>;
          }
        }
        return [];
      } else {
        print("Error obteniendo historial: ${response.statusCode} - ${response.body}");
        throw Exception("Error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      print("Excepción al obtener historial del oráculo: $e");
      rethrow;
    }
  }

  // DELETE /api/user/history/{id}
  Future<Map<String, dynamic>> deleteConsultation(int consultationId) async {
    final token = await _authService.getToken();
    final url = Uri.parse('$_baseUrl/user/history/$consultationId');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Consulta eliminada exitosamente',
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Error al eliminar la consulta',
        };
      }
    } catch (e) {
      print("Error deleting consultation: $e");
      return {'success': false, 'message': 'Excepción: $e'};
    }
  }
}
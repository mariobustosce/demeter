import 'dart:async';

import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'coin_balance.dart';

class OracleService {
  ApiClient get _api => ApiClient.instance;

  Future<Map<String, dynamic>> consultarAlOraculo({
    required String pregunta,
    required String nivelContexto,
    required bool usaCartaAstral,
    String? cartaAstralId,
    Map<String, dynamic>? contextoCompleto,
  }) async {
    final payload = {
      "pregunta": pregunta,
      "nivel_contexto": nivelContexto, // 'basico', 'intermedio', 'premium'
      "usa_carta_astral": usaCartaAstral,
      "carta_astral_id": usaCartaAstral ? cartaAstralId : null,
      "contexto_completo": contextoCompleto ?? {},
    };

    try {
      final responseData = jsonMap(await _api.post(
        '/oraculo/consultar',
        body: payload,
        timeout: kOracleTimeout,
      ));

      updateCoinBalance(responseData['nuevo_balance']);
      if (responseData['success'] == true) {
        return {
          'success': true,
          'response': responseData['response'],
          'nuevoBalance': responseData['nuevo_balance'],
        };
      }
      return {
        'success': false,
        'error': responseData['error'] ?? 'Error desconocido',
      };
    } on InsufficientCoinsException catch (e) {
      return _insufficientCoins(e);
    } catch (e) {
      return _failed(e);
    }
  }

  Future<Map<String, dynamic>> consultarCompatibilidad({
    required String cartaAId,
    required String cartaBId,
    String nivelContexto = 'intermedio',
  }) async {
    final payload = {
      "carta_a_id": cartaAId,
      "carta_b_id": cartaBId,
      "nivel_contexto": nivelContexto,
    };

    try {
      final responseData = jsonMap(await _api.post(
        '/oraculo/compatibilidad',
        body: payload,
        timeout: kOracleTimeout,
      ));

      updateCoinBalance(responseData['nuevo_balance']);
      if (responseData['success'] == true) {
        return {
          'success': true,
          'texto': responseData['texto'] ?? responseData['response'],
          'nuevoBalance': responseData['nuevo_balance'],
        };
      }
      return {
        'success': false,
        'error': responseData['error'] ?? 'Error desconocido',
      };
    } on InsufficientCoinsException catch (e) {
      return _insufficientCoins(e);
    } catch (e) {
      return _failed(e);
    }
  }

  Future<List<dynamic>> getHistorialConsultas() async {
    try {
      final decoded = await _api.get('/user/history');
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
    } catch (e) {
      debugPrint("Excepción al obtener historial del oráculo: $e");
      rethrow;
    }
  }

  // DELETE /api/user/history/{id}
  Future<Map<String, dynamic>> deleteConsultation(int consultationId) async {
    try {
      final responseData = await _api.delete('/user/history/$consultationId');
      return {
        'success': true,
        'message': apiMessage(responseData) ?? 'Consulta eliminada exitosamente',
      };
    } catch (e) {
      debugPrint("Error deleting consultation: $e");
      return {
        'success': false,
        'message': e is ApiException ? e.message : 'Error al eliminar la consulta',
      };
    }
  }

  // El ApiClient ya abrió la tienda; esto es el mensaje para la pantalla.
  Map<String, dynamic> _insufficientCoins(InsufficientCoinsException e) {
    updateCoinBalance(e.balance);
    return {
      'success': false,
      'error': 'Polvo estelar insuficiente',
      'details': 'Necesitas ${e.required} y tienes ${e.balance}.',
    };
  }

  // Si la IA falló, el servidor devolvió el polvo pero el error no trae
  // `nuevo_balance`: el saldo se vuelve a pedir a /me.
  Map<String, dynamic> _failed(Object e) {
    unawaited(AuthService().getMe());
    return {
      'success': false,
      'error': e is ApiException ? e.message : 'Error desconocido',
    };
  }
}

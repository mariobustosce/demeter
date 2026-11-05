import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/carta.dart';
import '../models/firmamento.dart';
import 'api_client.dart';
import 'coin_balance.dart';

class AstralChartService {
  AstralChartService({ApiClient? api}) : _apiOverride = api;

  final ApiClient? _apiOverride;
  ApiClient get _api => _apiOverride ?? ApiClient.instance;

  // GET /api/user/charts
  Future<List<dynamic>> getUserCharts() async {
    try {
      final data = await _api.get('/user/charts');
      if (data is List) return data;
      if (data is Map && data['data'] is List) return data['data'] as List;
      return [];
    } catch (e) {
      debugPrint("Error fetching user charts: $e");
      return [];
    }
  }

  /// GET /api/user/charts/{id}. Si la carta era del motor anterior, el
  /// servidor la recalcula antes de responder. Un 404 es «no existe».
  Future<FirmamentoDetalle> detalle(int id) async {
    final body = jsonMap(await _api.get('/user/charts/$id'));
    return FirmamentoDetalle.fromJson(body['data']) ??
        (throw const ApiException('Respuesta inesperada del servidor.'));
  }

  /// PATCH /api/user/charts/{id}/zona: cambia la zona (nombre IANA) y
  /// recalcula. La hora local anotada no cambia. Devuelve el detalle nuevo y
  /// el mensaje del servidor; lanza [ApiException] (422, 429, 404).
  Future<({FirmamentoDetalle detalle, String? message})> cambiarZona(int id, String timezone) async {
    final body = jsonMap(await _api.patch('/user/charts/$id/zona', body: {'timezone': timezone}));
    final detalle = FirmamentoDetalle.fromJson(body['data']) ??
        (throw const ApiException('Respuesta inesperada del servidor.'));
    return (detalle: detalle, message: apiMessage(body));
  }

  /// POST /api/user/charts/{id}/notas: una nota propia (250 como máximo).
  Future<NotaFirmamento> agregarNota(int id, String contenido) async {
    final body = jsonMap(await _api.post('/user/charts/$id/notas', body: {'contenido': contenido}));
    return NotaFirmamento.fromJson(body['nota']) ??
        (throw const ApiException('Respuesta inesperada del servidor.'));
  }

  /// POST /api/user/charts/{id}/notas/ia: la lectura de la IA, que cobra
  /// polvo estelar. Pone al día [coinBalance]. Sin saldo lanza
  /// [InsufficientCoinsException]; si el proveedor falla (502) no cobra.
  Future<NotaFirmamento> notaIA(int id) async {
    final body = jsonMap(await _api.post('/user/charts/$id/notas/ia', timeout: kOracleTimeout));
    updateCoinBalance(body['nuevo_balance']);
    return NotaFirmamento.fromJson(body['nota']) ??
        (throw const ApiException('Respuesta inesperada del servidor.'));
  }

  /// GET /api/user/zona: la zona IANA del lugar y el desfase que regía esa
  /// fecha y hora. Lanza [ApiException] si falla. Lleva coordenadas en la
  /// query (lo pide el contrato): no se registra.
  Future<ZonaLugar> zona({
    required double lat,
    required double lon,
    String? fecha,
    String? hora,
  }) async {
    final data = await _api.get('/user/zona', query: {
      'lat': lat.toStringAsFixed(4),
      'lon': lon.toStringAsFixed(4),
      if (fecha != null && fecha.isNotEmpty) 'fecha': fecha,
      if (hora != null && hora.isNotEmpty) 'hora': hora,
    });
    return ZonaLugar.fromJson(data) ??
        (throw const ApiException('Respuesta inesperada del servidor.'));
  }

  // POST /api/user/charts. Sin [timezone], el servidor usa la del lugar.
  Future<Map<String, dynamic>> createChart({
    required String title,
    required String birthDate,
    required String birthTime,
    required double birthLat,
    required double birthLon,
    String? timezone,
  }) async {
    try {
      final data = await _api.post(
        '/user/charts',
        body: {
          'titulo': title,
          'birth_date': birthDate,
          'birth_time': birthTime,
          // Con más de 4 decimales el servidor no detecta la carta repetida.
          'birth_lat': double.parse(birthLat.toStringAsFixed(4)),
          'birth_lon': double.parse(birthLon.toStringAsFixed(4)),
          'timezone': ?timezone,
        },
      );
      return {'success': true, 'data': data};
    } on ValidationException catch (e) {
      return {'success': false, 'message': e.message, 'errors': e.fieldErrors};
    } catch (e) {
      debugPrint("Error creating astral chart: $e");
      return {
        'success': false,
        'message': e is ApiException ? e.message : 'Error al crear el firmamento',
      };
    }
  }

  // DELETE /api/user/charts/{id}
  Future<Map<String, dynamic>> deleteChart(int chartId) async {
    try {
      final data = await _api.delete('/user/charts/$chartId');
      return {
        'success': true,
        'message': apiMessage(data) ?? 'Firmamento eliminado',
      };
    } catch (e) {
      debugPrint("Error deleting astral chart: $e");
      return {
        'success': false,
        'message': e is ApiException ? e.message : 'Error al eliminar el firmamento',
      };
    }
  }
}

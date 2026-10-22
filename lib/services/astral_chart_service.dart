import 'package:flutter/foundation.dart';
import 'api_client.dart';

class AstralChartService {
  ApiClient get _api => ApiClient.instance;

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
      final data = await _api.post(
        '/user/charts',
        body: {
          'titulo': title,
          'birth_date': birthDate,
          'birth_time': birthTime,
          'birth_lat': birthLat,
          'birth_lon': birthLon,
          'timezone': timezone,
        },
      );
      return {'success': true, 'data': data};
    } on ValidationException catch (e) {
      return {'success': false, 'message': e.message, 'errors': e.fieldErrors};
    } catch (e) {
      debugPrint("Error creating astral chart: $e");
      return {
        'success': false,
        'message': e is ApiException ? e.message : 'Error al crear la carta astral',
      };
    }
  }

  // DELETE /api/user/charts/{id}
  Future<Map<String, dynamic>> deleteChart(int chartId) async {
    try {
      final data = await _api.delete('/user/charts/$chartId');
      return {
        'success': true,
        'message': apiMessage(data) ?? 'Carta astral eliminada exitosamente',
      };
    } catch (e) {
      debugPrint("Error deleting astral chart: $e");
      return {
        'success': false,
        'message': e is ApiException ? e.message : 'Error al eliminar la carta astral',
      };
    }
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/checkout_response.dart';
import '../models/order_status_response.dart';
import '../models/store_package.dart';
import 'api_config.dart';
import 'auth_service.dart';

class StoreService {
  final String _baseUrl = ApiConfig.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  String _readErrorMessage(Map<String, dynamic> body, String fallback) {
    if (body['message'] != null) {
      return body['message'].toString();
    }
    return fallback;
  }

  Future<List<StorePackage>> getPackages() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/store/packages'),
      headers: await _getHeaders(),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      final data = (body['data'] as List?) ?? const [];
      return data
          .whereType<Map>()
          .map((item) => StorePackage.fromJson(item.cast<String, dynamic>()))
          .toList();
    }

    throw Exception(
      _readErrorMessage(body, 'No se pudieron cargar los paquetes.'),
    );
  }

  Future<CheckoutResponse> createCheckout(int packageId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/store/checkout'),
      headers: await _getHeaders(),
      body: jsonEncode({'package_id': packageId}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      return CheckoutResponse.fromJson(body);
    }

    throw Exception(_readErrorMessage(body, 'No se pudo iniciar el checkout.'));
  }

  Future<OrderStatusResponse> getOrderStatus(String externalReference) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/store/orders/$externalReference'),
      headers: await _getHeaders(),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return OrderStatusResponse.fromJson(body);
    }

    throw Exception(
      _readErrorMessage(body, 'No se pudo consultar el estado de la orden.'),
    );
  }
}

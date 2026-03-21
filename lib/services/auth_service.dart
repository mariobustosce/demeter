import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  // CONFIGURACIÓN:
  // Usa "http://10.0.2.2/api" para el Emulador de Android.
  // Usa tu IP local (ej "http://192.168.1.XX/api") si usas un celular físico.
  // Usa "http://localhost/api" si lo pruebas en Web o Windows.
  final String _baseUrl = "https://windowsdemeter.com/api"; 

  // Guardar el Token de manera persistente
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sanctum_token', token);
  }

  // Recuperar el Token almacenado
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('sanctum_token');
  }

  // MÉTODO CENTRALIZADO DE HEADERS
  Future<Map<String, String>> _getHeaders() async {
    String? token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Login contra Laravel Sanctum
  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'email': email,
          'password': password,
          'device_name': 'flutter_demeter_app', // Requerido por Sanctum
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Ajusta la clave ('token', 'access_token') según tu respuesta de Laravel
        final token = data['token'] ?? data['access_token'];
        
        if (token != null) {
          await _saveToken(token);
          return true;
        }
      }
      return false;
    } catch (e) {
      print("Error haciendo login: $e");
      return false;
    }
  }

  // Obtener datos del usuario logueado (Devuelve objeto User)
  Future<User?> getMe() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/me'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      print("Error obteniendo usuario: $e");
    }
    return null;
  }

  // Cerrar sesión
  Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/logout'),
        headers: await _getHeaders(),
      );
    } catch (_) {}
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sanctum_token');
  }
}


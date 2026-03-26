import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  // Login con Google
  Future<bool> loginWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: '829473466086-5k1fc5lmsn721hmqjgba0hdhk5fkjkbm.apps.googleusercontent.com',
        serverClientId: '829473466086-5k1fc5lmsn721hmqjgba0hdhk5fkjkbm.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );

      // Usado para limpiar la sesión previa en caso de ser necesario
      await googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return false; // El usuario canceló
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken ?? googleAuth.accessToken;

      if (idToken == null) {
        print("No se pudo obtener el idToken de Google");
        return false;
      }

      // Enviar token a nuestro backend de Laravel
      final response = await http.post(
        Uri.parse('$_baseUrl/login/google'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'token': idToken,
          'device_name': 'flutter_demeter_app',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] ?? data['access_token'];
        
        if (token != null) {
          await _saveToken(token);
          return true;
        }
      } else {
        print("Error del backend al hacer login con Google: ${response.statusCode} - ${response.body}");
      }
      return false;
    } catch (e) {
      print("Error en loginWithGoogle: $e");
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


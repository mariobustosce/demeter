import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/auth_response.dart';
import '../models/user.dart';
import 'api_config.dart';

class AuthService {
  final String _baseUrl = ApiConfig.baseUrl;

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

  String _readErrorMessage(
    dynamic body, [
    String fallback = 'Ocurrió un error de autenticación',
  ]) {
    if (body is Map<String, dynamic>) {
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
    }

    return fallback;
  }

  AuthResponse _parseAuthResponse(Map<String, dynamic> body) {
    final response = AuthResponse.fromJson(body);
    if (response.accessToken.isEmpty) {
      throw Exception('La API no devolvió access_token.');
    }
    return response;
  }

  Future<AuthResponse> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'email': email,
        'password': password,
        'device_name': ApiConfig.deviceName,
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      final authResponse = _parseAuthResponse(body);
      await _saveToken(authResponse.accessToken);
      return authResponse;
    }

    throw Exception(_readErrorMessage(body, 'No se pudo iniciar sesión.'));
  }

  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? referralCode,
  }) async {
    final payload = {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'device_name': ApiConfig.deviceName,
      if (referralCode != null && referralCode.trim().isNotEmpty)
        'referral_code': referralCode.trim(),
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/register'),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      final authResponse = _parseAuthResponse(body);
      await _saveToken(authResponse.accessToken);
      return authResponse;
    }

    throw Exception(_readErrorMessage(body, 'No se pudo crear la cuenta.'));
  }

  Future<AuthResponse> loginWithGoogle() async {
    try {
      // 1. Iniciar el flujo de Google indicando el "Web Client ID" para que retorne el idToken
      // Extraído directamente desde tu google-services.json actualizado
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: '179031827037-a30j3hhgvjkgqdupehgsmortejj9olji.apps.googleusercontent.com',
      );
      
      // Limpiamos sesión previa
      await googleSignIn.signOut();

      // 2. Mostrar modal de cuentas
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('El inicio de sesión fue cancelado por el usuario.');
      }

      // 3. Obtener credenciales de Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 4. Crear una nueva credencial para Firebase Auth y autenticar en Firebase
      final fba.AuthCredential credential = fba.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final fba.UserCredential fbaUserCredential = 
          await fba.FirebaseAuth.instance.signInWithCredential(credential);

      final fba.User? firebaseUser = fbaUserCredential.user;
      
      if (firebaseUser == null) {
         throw Exception('Ocurrió un error en Firebase al intentar iniciar sesión');
      }

      // 5. Finalmente obtenemos el idToken de Firebase 
      // (Opcional, si todavía necesitas enviarlo a tu API backend)
      final String? idToken = await firebaseUser.getIdToken();
      if (idToken == null) {
        throw Exception('No se pudo obtener el token de identidad de Firebase.');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/login/google'),
        headers: await _getHeaders(),
        body: jsonEncode({
          // ¡EUREKA! Tu backend de Laravel ("sanctum" o "socialite") espera validar el token original de Google
          // y nosotros le estábamos enviando el ID token interno the Firebase.
          'token': googleAuth.idToken ?? googleAuth.accessToken,
          'device_name': ApiConfig.deviceName,
        }),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final authResponse = _parseAuthResponse(body);
        await _saveToken(authResponse.accessToken);
        return authResponse;
      }

      throw Exception(
        _readErrorMessage(body, 'No se pudo iniciar sesión con Google.'),
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Error en login con Google.');
    }
  }

  Future<User?> getMe() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/me'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final userData = data['data'] ?? data['user'] ?? data;
        return User.fromJson(userData);
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

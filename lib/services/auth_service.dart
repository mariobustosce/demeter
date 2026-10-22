import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;
import 'package:google_sign_in/google_sign_in.dart';
import '../config/app_config.dart';
import '../models/auth_response.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'token_store.dart';

class AuthService {
  ApiClient get _api => ApiClient.instance;
  final TokenStore _tokens = TokenStore();

  // Igual para todas las instalaciones hasta el paso 3 de la fase 1.
  static const String _deviceName = 'flutter_demeter_app';

  // Recuperar el Token almacenado
  Future<String?> getToken() => _tokens.read();

  Future<AuthResponse> _saveSession(dynamic body) async {
    final response = AuthResponse.fromJson(jsonMap(body));
    if (response.accessToken.isEmpty) {
      throw Exception('La API no devolvió access_token.');
    }
    await _tokens.write(response.accessToken);
    return response;
  }

  Future<AuthResponse> login(String email, String password) async {
    final body = await _api.post(
      '/login',
      auth: false,
      body: {
        'email': email,
        'password': password,
        'device_name': _deviceName,
      },
    );
    return _saveSession(body);
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
      'device_name': _deviceName,
      if (referralCode != null && referralCode.trim().isNotEmpty)
        'referral_code': referralCode.trim(),
    };

    final body = await _api.post('/register', auth: false, body: payload);
    return _saveSession(body);
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

      // DEBUG: verificar qué tokens retorna Google
      debugPrint('[Google Login] idToken: ${googleAuth.idToken != null ? "OK (${googleAuth.idToken!.length} chars)" : "NULL"}');
      debugPrint('[Google Login] accessToken: ${googleAuth.accessToken != null ? "OK" : "NULL"}');
      debugPrint('[Google Login] Firebase idToken: OK (${idToken.length} chars)');

      final tokenToSend = googleAuth.accessToken;
      debugPrint('[Google Login] Token enviado al backend: ${tokenToSend != null ? "OK" : "NULL"}');

      final body = await _api.post(
        '/login/google',
        auth: false,
        body: {
          'token': tokenToSend,
          'device_name': _deviceName,
        },
      );
      return _saveSession(body);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Error en login con Google.');
    }
  }

  Future<User?> getMe() async {
    try {
      // Timeout corto: esta llamada bloquea el splash.
      final data = await _api.get('/me', timeout: kAuthTimeout);
      if (data is Map<String, dynamic>) {
        final userData = data['data'] ?? data['user'] ?? data;
        return User.fromJson(userData);
      }
    } catch (e) {
      debugPrint("Error obteniendo usuario: $e");
    }
    return null;
  }

  // Cerrar sesión
  Future<void> logout() async {
    try {
      await _api.post('/logout');
    } catch (_) {}

    await _tokens.clear();
  }
}

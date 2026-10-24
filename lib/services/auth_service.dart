import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fba;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config/app_config.dart';
import '../models/auth_response.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'coin_balance.dart';
import 'device_name.dart';
import 'token_store.dart';

class AuthService {
  ApiClient get _api => ApiClient.instance;
  final TokenStore _tokens = TokenStore();

  // Recuperar el Token almacenado
  Future<String?> getToken() => _tokens.read();

  Future<AuthResponse> _saveSession(dynamic body) async {
    final response = AuthResponse.fromJson(jsonMap(body));
    if (response.accessToken.isEmpty) {
      throw Exception('La API no devolvió access_token.');
    }
    await _tokens.write(response.accessToken);
    coinBalance.value = response.user.celestialCoins;
    return response;
  }

  /// Login con correo. Si la cuenta tiene 2FA todavía no hay sesión: lanza
  /// [TwoFactorRequired] y el token sale de [loginTwoFactor].
  Future<AuthResponse> login(String email, String password) async {
    final body = jsonMap(await _api.post(
      '/login',
      auth: false,
      body: {
        'email': email,
        'password': password,
        'device_name': await DeviceName.get(),
      },
    ));
    if (body['two_factor'] == true) {
      final desafio = body['desafio'];
      if (desafio is! String || desafio.isEmpty) {
        throw const ApiException('Respuesta inesperada del servidor.');
      }
      throw TwoFactorRequired(desafio);
    }
    return _saveSession(body);
  }

  /// Segundo paso del login con 2FA, con el código de la app autenticadora o
  /// uno de recuperación. Si no vale o el desafío venció (dura 5 minutos), el
  /// servidor responde 422 con el motivo.
  Future<AuthResponse> loginTwoFactor({
    required String desafio,
    String? code,
    String? recoveryCode,
  }) async {
    final body = await _api.post(
      '/login/2fa',
      auth: false,
      body: {
        'desafio': desafio,
        'code': ?code,
        'recovery_code': ?recoveryCode,
        'device_name': await DeviceName.get(),
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
      'device_name': await DeviceName.get(),
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

      // 5. El servidor verifica el ID token de Firebase, no el access token
      // de Google.
      final String? idToken = await firebaseUser.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw Exception('No se pudo obtener el token de identidad de Firebase.');
      }

      final body = await _api.post(
        '/login/google',
        auth: false,
        body: {
          'id_token': idToken,
          'device_name': await DeviceName.get(),
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
        final user = User.fromJson(userData);
        coinBalance.value = user.celestialCoins;
        return user;
      }
    } catch (e) {
      debugPrint("Error obteniendo usuario: $e");
    }
    return null;
  }

  /// Cierra la sesión en el servidor y borra lo del usuario en el equipo.
  Future<void> logout() async {
    // Fase 4: antes de esto, DELETE /api/dispositivos {fcm_token}.
    await _quietly(() => _api.post('/logout'));
    await clearLocalSession();
  }

  /// Borra la sesión y los datos del usuario en el equipo, sin hablar con el
  /// servidor (también sirve tras un 401). Cada paso sigue aunque otro falle.
  /// El nombre de la instalación se queda: con él el servidor revoca los
  /// tokens viejos.
  Future<void> clearLocalSession() async {
    await _quietly(_tokens.clear);
    coinBalance.value = null;
    await _quietly(() => fba.FirebaseAuth.instance.signOut());
    await _quietly(() => GoogleSignIn().signOut());
    await _quietly(_clearWebView);
    // Todo lo que hay en prefs es del usuario: coordenadas y el último cielo.
    await _quietly(() async => (await SharedPreferences.getInstance()).clear());
  }

  // Cookies, caché y almacenamiento son del sistema: valen para cualquier
  // WebView de la app.
  static Future<void> _clearWebView() async {
    await WebViewCookieManager().clearCookies();
    final controller = WebViewController();
    await controller.clearCache();
    await controller.clearLocalStorage();
  }

  static Future<void> _quietly(Future<void> Function() step) async {
    try {
      await step();
    } catch (e) {
      debugPrint('Logout: un paso falló (${e.runtimeType}).');
    }
  }
}

/// La cuenta tiene 2FA: falta el código. No es un error para mostrar, y el
/// desafío no se registra en ningún lado.
class TwoFactorRequired implements Exception {
  const TwoFactorRequired(this.desafio);

  final String desafio;
}

import 'package:demeter/config/app_config.dart';
import 'package:demeter/main.dart';
import 'package:demeter/screens/guest_map_screen.dart';
import 'package:demeter/screens/login_screen.dart';
import 'package:demeter/screens/splash_screen.dart';
import 'package:demeter/services/location_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'fakes/fake_webview.dart';

/// Permiso de ubicación bloqueado: el mapa carga sin lat/lon y sin diálogo.
class _SinUbicacion extends LocationService {
  @override
  Future<LocationAccess> access() async => LocationAccess.blocked;

  @override
  Future<bool> request() async => false;

  @override
  Future<RoundedLocation?> current() async => null;
}

/// El flujo completo de la fase 7: la app arranca sin sesión, el splash lleva
/// al mapa de invitado y «Entrar al portal» abre el login de verdad.
void main() {
  testWidgets('sin sesión: del splash al mapa de invitado y de ahí al login',
      (tester) async {
    final platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    GuestMapScreen.resetInvite();
    LocationService.instance = _SinUbicacion();

    await tester.pumpWidget(const MyApp());
    expect(find.byType(SplashScreen), findsOneWidget);

    // El splash espera su mínimo, no encuentra token y va al invitado.
    await tester.pump(kSplashMinDuration);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(GuestMapScreen), findsOneWidget);
    expect(platform.last.loaded.last.path, '/app/mapa/basico',
        reason: 'el invitado carga el mapa kiosk sin token');

    await tester.tap(find.text('Entrar al portal'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}

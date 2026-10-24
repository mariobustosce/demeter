import 'dart:convert';

import 'package:demeter/config/app_config.dart';
import 'package:demeter/main.dart';
import 'package:demeter/screens/guest_map_screen.dart';
import 'package:demeter/screens/login_screen.dart';
import 'package:demeter/screens/store_screen.dart';
import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/location_service.dart';
import 'package:demeter/services/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'fakes/fake_webview.dart';

class _SinUbicacion extends LocationService {
  @override
  Future<LocationAccess> access() async => LocationAccess.blocked;

  @override
  Future<bool> request() async => false;

  @override
  Future<RoundedLocation?> current() async => null;
}

/// El cableado global de main.dart: desde cualquier pantalla, el 401 deja la
/// pila solo con el mapa de invitado y el 403 insufficient_coins abre la
/// tienda.
void main() {
  setUp(() {
    WebViewPlatform.instance = FakeWebViewPlatform();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    GuestMapScreen.resetInvite();
    LocationService.instance = _SinUbicacion();
  });

  Future<void> frames(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> hastaInvitado(WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(kSplashMinDuration);
    await frames(tester);
    expect(find.byType(GuestMapScreen), findsOneWidget);
  }

  testWidgets('un 401 del API limpia la sesión y deja solo el mapa de invitado',
      (tester) async {
    ApiClient.instance = ApiClient(
      httpClient: MockClient((_) async =>
          http.Response(jsonEncode({'message': 'Sesión caducada'}), 401)),
      baseUrl: 'https://api.test/api/',
    );
    wireGlobalApiErrors();

    await hastaInvitado(tester);
    await tester.tap(find.text('Entrar al portal'));
    await frames(tester);
    expect(find.byType(LoginScreen), findsOneWidget);

    // Con una «sesión» guardada, la siguiente llamada recibe el 401.
    await TokenStore().write('tok-rechazado');
    await expectLater(
      ApiClient.instance.get('/perfil'),
      throwsA(isA<ApiException>()),
    );
    await frames(tester);

    expect(find.byType(LoginScreen), findsNothing,
        reason: 'pushNamedAndRemoveUntil vacía la pila');
    expect(find.byType(GuestMapScreen), findsOneWidget);
    expect(await TokenStore().read(), isNull);
  });

  testWidgets('el 403 insufficient_coins abre la tienda', (tester) async {
    ApiClient.instance = ApiClient(
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/me')) {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 1,
                'name': 'Ana',
                'email': 'ana@test.cl',
                'celestial_coins': 2,
              },
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      }),
      baseUrl: 'https://api.test/api/',
    );
    wireGlobalApiErrors();

    await hastaInvitado(tester);
    ApiClient.instance.onInsufficientCoins?.call(
      const InsufficientCoinsException('No te alcanza', required: 100, balance: 2),
    );
    await frames(tester);

    expect(find.byType(StoreScreen), findsOneWidget);
  });
}

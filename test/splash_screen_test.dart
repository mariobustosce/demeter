import 'dart:convert';

import 'package:demeter/config/app_config.dart';
import 'package:demeter/screens/splash_screen.dart';
import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/token_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La decisión del splash: sin token, invitado; con token válido, /home; con
/// token rechazado, invitado y el token borrado.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ApiClient clientWith(MockClientHandler handler) => ApiClient(
        httpClient: MockClient(handler),
        baseUrl: 'https://api.test/api/',
      );

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: const SplashScreen(),
      routes: {
        kGuestRoute: (_) => const Scaffold(body: Text('INVITADO')),
        '/home': (_) => const Scaffold(body: Text('HOME')),
      },
    ));
    await tester.pump(kSplashMinDuration);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('sin token va al mapa de invitado sin llamar al API',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    var llamadas = 0;
    ApiClient.instance = clientWith((_) async {
      llamadas++;
      return http.Response('{}', 200);
    });

    await open(tester);

    expect(find.text('INVITADO'), findsOneWidget);
    expect(llamadas, 0, reason: 'sin token no hay nada que verificar');
  });

  testWidgets('con token y /me OK entra a /home', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    ApiClient.instance = clientWith((_) async => http.Response(
          jsonEncode({
            'data': {
              'id': 1,
              'name': 'Ana',
              'email': 'ana@test.cl',
              'celestial_coins': 5,
            },
          }),
          200,
        ));

    await open(tester);

    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('con el token rechazado (401) queda borrado y se entra de invitado',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-caducado'});
    ApiClient.instance = clientWith(
        (_) async => http.Response(jsonEncode({'message': 'caducado'}), 401));

    await open(tester);

    expect(find.text('INVITADO'), findsOneWidget);
    expect(await TokenStore().read(), isNull);
  });
}

import 'dart:convert';

import 'package:demeter/screens/landscapes_screen.dart';
import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/coin_balance.dart';
import 'package:demeter/services/landscape_thumbnails.dart';
import 'package:demeter/services/landscapes_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes/landscape_json.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

void main() {
  late List<http.Request> requests;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    coinBalance.value = null;
    requests = [];
    LandscapeThumbnails.instance = LandscapeThumbnails(
      httpClient: MockClient((_) async => http.Response('', 404)),
      directory: () async => null,
    );
  });

  LandscapesService service() => LandscapesService(
        api: ApiClient(
          baseUrl: 'https://windowsdemeter.com/api',
          httpClient: MockClient((req) async {
            requests.add(req);
            final body = req.method == 'GET'
                ? {
                    'success': true,
                    'saldo': 1000,
                    'paisajes': [
                      landscapeJson('cordillera', isDefault: true),
                      landscapeJson('castillo-wulff', premium: true, canUse: false),
                    ],
                  }
                : {
                    'success': true,
                    'saldo': 900,
                    'paisaje': landscapeJson('castillo-wulff', premium: true, purchased: true),
                  };
            return http.Response(jsonEncode(body), 200, headers: _json);
          }),
        ),
      );

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('«Mis paisajes»: los premium con 🔒 y precio, y se compran', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LandscapesScreen(service: service())));
    await frames(tester);

    expect(find.text('Mis paisajes'), findsOneWidget);
    expect(find.text('1000 ✨'), findsOneWidget);
    expect(find.text('El de siempre'), findsOneWidget);
    expect(find.text('🔒 100 ✨'), findsOneWidget);

    await tester.tap(find.text('Comprar por 100 ✨'));
    await frames(tester);
    await tester.tap(find.text('Comprar'));
    await frames(tester);

    expect(requests.last.url.path, '/api/paisajes/castillo-wulff/comprar');
    expect(find.text('Comprado ✓'), findsOneWidget);
    expect(find.text('Comprar por 100 ✨'), findsNothing);
    expect(find.text('900 ✨'), findsOneWidget);
    expect(
      find.text('¡Tuyo! «Paisaje castillo-wulff» ya está desbloqueado para tus lugares.'),
      findsOneWidget,
    );
  });

  testWidgets('si cancela la confirmación no se gasta nada', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LandscapesScreen(service: service())));
    await frames(tester);

    await tester.tap(find.text('Comprar por 100 ✨'));
    await frames(tester);
    await tester.tap(find.text('Cancelar'));
    await frames(tester);

    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    expect(find.text('🔒 100 ✨'), findsOneWidget);
  });
}

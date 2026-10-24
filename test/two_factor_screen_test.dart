import 'dart:convert';

import 'package:demeter/screens/two_factor_screen.dart';
import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/device_name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late List<Map<String, dynamic>> sent;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'device_name': 'android:abc'});
    DeviceName.resetForTest();
    sent = [];
  });

  void serverAnswers(int status, Object body) {
    ApiClient.instance = ApiClient(
      httpClient: MockClient((req) async {
        sent.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response(jsonEncode(body), status);
      }),
      baseUrl: 'https://api.test/api',
    );
  }

  Future<void> pumpScreen(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          home: const TwoFactorScreen(desafio: 'd-1'),
          routes: {'/home': (_) => const Text('HOME')},
        ),
      );

  testWidgets('código válido: entra a /home', (tester) async {
    serverAnswers(200, {
      'access_token': 'tok-2',
      'user': {'id': 1, 'name': 'A', 'email': 'a@a.test'},
    });
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), '12a3456789');
    await tester.tap(find.text('VERIFICAR'));
    await tester.pumpAndSettle();

    expect(sent.single['code'], '123456'); // Solo dígitos, máximo 6.
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('código de recuperación y error del servidor', (tester) async {
    serverAnswers(422, {'message': 'El código no es válido.'});
    await pumpScreen(tester);

    await tester.tap(find.text('Usar un código de recuperación'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'abcde-fghij');
    await tester.tap(find.text('VERIFICAR'));
    await tester.pumpAndSettle();

    expect(sent.single['recovery_code'], 'abcde-fghij');
    expect(sent.single.containsKey('code'), isFalse);
    expect(find.text('El código no es válido.'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });
}

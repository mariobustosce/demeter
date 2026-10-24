import 'package:demeter/config/app_config.dart';
import 'package:demeter/models/map_mode.dart';
import 'package:demeter/screens/guest_map_screen.dart';
import 'package:demeter/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'fakes/fake_webview.dart';

class FakeLocation extends LocationService {
  FakeLocation(this.state, {this.grants = true});

  LocationAccess state;
  final bool grants;
  int requests = 0;

  @override
  Future<LocationAccess> access() async => state;

  @override
  Future<bool> request() async {
    requests++;
    if (grants) state = LocationAccess.granted;
    return grants;
  }

  @override
  Future<RoundedLocation?> current() async => state == LocationAccess.granted
      ? RoundedLocation(-33.456789, -70.648123)
      : null;
}

void main() {
  late FakeWebViewPlatform platform;

  setUp(() {
    platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    SharedPreferences.setMockInitialValues({});
    GuestMapScreen.resetInvite();
  });

  Future<void> open(WidgetTester tester, LocationService location) async {
    LocationService.instance = location;
    await tester.pumpWidget(MaterialApp(
      home: const GuestMapScreen(),
      routes: {
        '/login': (_) => const Scaffold(body: Text('LOGIN')),
        '/register': (_) => const Scaffold(body: Text('REGISTRO')),
      },
    ));
    await tester.pump();
  }

  Future<void> frames(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Uri loaded() => platform.last.loaded.last;

  testWidgets('explica antes de pedir el permiso y manda la ubicación redondeada',
      (tester) async {
    final location = FakeLocation(LocationAccess.askable);
    await open(tester, location);
    await frames(tester);

    expect(find.text('Tu cielo, desde donde estás'), findsOneWidget);
    expect(location.requests, 0, reason: 'el sistema no pregunta antes que la app');

    await tester.tap(find.text('Continuar'));
    await frames(tester);

    expect(location.requests, 1);
    expect(loaded().path, '/app/mapa/basico');
    expect(loaded().queryParameters['lat'], '-33.46');
    expect(loaded().queryParameters['lon'], '-70.65');
  });

  testWidgets('si dice que no, carga sin lat/lon y no vuelve a preguntar solo',
      (tester) async {
    final location = FakeLocation(LocationAccess.askable);
    await open(tester, location);
    await frames(tester);

    await tester.tap(find.text('Ahora no'));
    await frames(tester);

    expect(location.requests, 0);
    expect(loaded().queryParameters.keys, ['ratio']);

    // Otra apertura: sin diálogo.
    await tester.pumpWidget(const SizedBox());
    await open(tester, location);
    await frames(tester);
    expect(find.text('Tu cielo, desde donde estás'), findsNothing);
    expect(loaded().queryParameters.containsKey('lat'), isFalse);
  });

  testWidgets('con el permiso bloqueado carga sin lat/lon y sin diálogo',
      (tester) async {
    await open(tester, FakeLocation(LocationAccess.blocked));
    await frames(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(loaded().queryParameters.containsKey('lat'), isFalse);
  });

  testWidgets('cambiar el modo recarga el mapa en ese modo', (tester) async {
    await open(tester, FakeLocation(LocationAccess.granted));
    await frames(tester);

    await tester.tap(find.text('Básico'));
    await frames(tester);
    await tester.tap(find.byType(CheckedPopupMenuItem<MapMode>).last);
    await frames(tester);

    expect(loaded().path, '/app/mapa/astronomico');
  });

  testWidgets('«Entrar al portal» abre el login', (tester) async {
    await open(tester, FakeLocation(LocationAccess.granted));
    await frames(tester);

    await tester.tap(find.text('Entrar al portal'));
    await frames(tester);

    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('pasados unos segundos sube la invitación a crear la cuenta',
      (tester) async {
    await open(tester, FakeLocation(LocationAccess.granted));
    await frames(tester);
    expect(find.text('Crear cuenta'), findsNothing);

    await tester.pump(kGuestInviteDelay);
    await frames(tester);
    expect(find.text('Crear cuenta'), findsOneWidget);

    await tester.tap(find.text('Crear cuenta'));
    await frames(tester);
    expect(find.text('REGISTRO'), findsOneWidget);
  });
}

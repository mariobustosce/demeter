import 'dart:convert';

import 'package:demeter/models/aviso.dart';
import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/push_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _fcm = 'fcm-token-de-prueba-con-mas-de-20-caracteres';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late int deletedTokens;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    PackageInfo.setMockInitialValues(
      appName: 'WindowsDemeter',
      packageName: 'com.windowsdemeter',
      version: '1.0.6',
      buildNumber: '10',
      buildSignature: '',
    );
    requests = [];
    deletedTokens = 0;
  });

  PushService service({String? token = _fcm}) => PushService(
        available: true,
        api: ApiClient(
          baseUrl: 'https://windowsdemeter.com/api',
          httpClient: MockClient((req) async {
            requests.add(req);
            return http.Response(jsonEncode({'success': true}), 201, headers: _json);
          }),
        ),
        getToken: () async => token,
        deleteToken: () async => deletedTokens++,
      );

  test('registra el teléfono con el token de FCM, la plataforma y la versión', () async {
    await service().register();

    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/dispositivos');
    expect(request.headers['Authorization'], 'Bearer tok-1');
    expect(jsonDecode(request.body), {
      'fcm_token': _fcm,
      'plataforma': 'android',
      'version_app': '1.0.6+10',
    });
  });

  test('sin sesión no registra nada', () async {
    FlutterSecureStorage.setMockInitialValues({});

    await service().register();

    expect(requests, isEmpty);
  });

  test('sin Firebase no hace nada', () async {
    final push = PushService(available: false, getToken: () async => _fcm);

    await push.register();
    await push.unregister();

    expect(requests, isEmpty);
  });

  test('al cerrar sesión borra en el servidor el token que registró', () async {
    final push = service();
    await push.register();
    requests.clear();

    await push.unregister();

    final request = requests.single;
    expect(request.method, 'DELETE');
    expect(request.url.path, '/api/dispositivos');
    expect(jsonDecode(request.body), {'fcm_token': _fcm});

    // Una segunda vez ya no hay nada que borrar.
    await push.unregister();
    expect(requests, hasLength(1));
  });

  test('si nunca se registró, no llama al servidor', () async {
    await service().unregister();

    expect(requests, isEmpty);
  });

  test('forget borra el token de FCM y el aviso pendiente', () async {
    final push = service();
    push.open({'aviso_id': 'a1', 'tipo': 'lluvia', 'titulo': 'T', 'texto': 'x'});

    await push.forget();

    expect(deletedTokens, 1);
    expect(push.openedAviso.value, isNull);
  });

  test('al tocar una notificación queda el aviso para abrirlo', () {
    final push = service();

    push.open({'tipo': 'lluvia', 'titulo': 'Sin id'});
    expect(push.openedAviso.value, isNull);

    push.open({'aviso_id': 'a1', 'tipo': 'helada', 'titulo': 'Helada', 'texto': '-3 °C'});
    final aviso = push.openedAviso.value;
    expect(aviso?.id, 'a1');
    expect(aviso?.type, 'helada');
    expect(aviso?.text, '-3 °C');
  });

  test('la notificación con la app abierta lleva lo mismo que el push', () {
    const aviso = Aviso(id: 'a1', type: 'sismo', title: 'Sismo', text: 'M 6,1');

    final payload = PushService.pushPayload(aviso);

    expect(payload, {'aviso_id': 'a1', 'tipo': 'sismo', 'titulo': 'Sismo', 'texto': 'M 6,1'});
    expect(payload.keys, isNot(contains('lat')));
    expect(Aviso.fromPush(payload)?.id, 'a1');
  });

  group('como una app de mensajes', () {
    PushService withPermission(List<String> calls, {required bool granted}) => PushService(
          available: true,
          hasPermission: () async {
            calls.add('has');
            return granted;
          },
          requestPermission: () async {
            calls.add('request');
            return true;
          },
        );

    test('al entrar se pide el permiso una sola vez', () async {
      SharedPreferences.setMockInitialValues({});
      final calls = <String>[];
      final push = withPermission(calls, granted: false);

      await push.askPermissionOnce();
      await push.askPermissionOnce();

      expect(calls, ['has', 'request']);
    });

    test('con el permiso ya dado no pregunta', () async {
      SharedPreferences.setMockInitialValues({});
      final calls = <String>[];

      await withPermission(calls, granted: true).askPermissionOnce();

      expect(calls, ['has']);
    });

    test('la notificación sale flotante, con sonido y agrupada', () {
      final details = PushService.avisoDetails(
        const Aviso(id: 'a1', type: 'lluvia', title: 'Lluvia mañana', text: '30 mm en Casa'),
      );

      expect(details.channelId, kAlertsChannelId);
      expect(details.importance, Importance.high);
      expect(details.priority, Priority.high);
      expect(details.category, AndroidNotificationCategory.message);
      expect(details.visibility, NotificationVisibility.private);
      expect(details.playSound, isTrue);
      expect(details.enableVibration, isTrue);
      expect(details.groupKey, isNotNull);
      expect(details.ticker, 'Lluvia mañana');
    });
  });
}

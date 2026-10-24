import 'package:demeter/models/wallpaper_link.dart';
import 'package:demeter/services/live_wallpaper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('windowsdemeter.com/wallpaper');
const _web = 'https://windowsdemeter.com';
const _url = '$_web/lively/m/tok123456789012345678/profesional';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late Object? Function(MethodCall call) answer;

  setUp(() {
    calls = [];
    answer = (_) => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return answer(call);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  LiveWallpaper android() => LiveWallpaper(channel: _channel, android: true, webBase: _web);

  test('pasa la URL, el favorito y el modo al servicio', () async {
    await android().configure(_url, favoriteId: 9, mode: WallpaperMode.profesional);

    expect(calls.single.method, 'configure');
    // Sin --dart-define de la prueba técnica, el servicio usa sus valores.
    expect(calls.single.arguments, {'url': _url, 'favorito': 9, 'modo': 'profesional'});
  });

  test('solo acepta la página del fondo de nuestro servidor', () async {
    for (final url in [
      'https://otro.com/lively/m/tok/basico',
      'http://windowsdemeter.com/lively/m/tok/basico',
      '$_web/app/mapa/t/tok/basico',
      '$_web/lively/m/../../app/basico',
      'https://user@windowsdemeter.com/lively/m/tok/basico',
    ]) {
      await expectLater(
        android().configure(url, favoriteId: 9, mode: WallpaperMode.basico),
        throwsArgumentError,
        reason: url,
      );
    }
    expect(calls, isEmpty);
  });

  test('lee el favorito y el modo guardados', () async {
    answer = (_) => {'favorito': 9, 'modo': 'rotativo'};
    expect(await android().current(), (favoriteId: 9, mode: WallpaperMode.rotativo));

    answer = (_) => {'favorito': 9, 'modo': 'otro'};
    expect(await android().current(), isNull);

    answer = (_) => null;
    expect(await android().current(), isNull);
  });

  test('si el lado nativo falla, el fondo no está', () async {
    answer = (_) => throw PlatformException(code: 'x');

    expect(await android().isActive(), isFalse);
    expect(await android().isSupported(), isFalse);
    expect(await android().openPicker(), isFalse);
  });

  test('fuera de Android no llama al canal', () async {
    final ios = LiveWallpaper(channel: _channel, android: false, webBase: _web);

    expect(await ios.isSupported(), isFalse);
    expect(await ios.current(), isNull);
    expect(
      ios.configure(_url, favoriteId: 9, mode: WallpaperMode.basico),
      throwsUnsupportedError,
    );
    expect(calls, isEmpty);
  });

  test('olvida las prefs del fondo anterior, con sus coordenadas', () async {
    SharedPreferences.setMockInitialValues({
      'wallpaper_auto_enabled': true,
      'wallpaper_lat': -33.45,
      'wallpaper_lon': -70.66,
      'wallpaper_target': 2,
      'wallpaper_last_refresh': 1700000000000,
      'map_mode': 'basico',
    });

    await forgetLegacyWallpaper();

    expect((await SharedPreferences.getInstance()).getKeys(), {'map_mode'});
  });
}

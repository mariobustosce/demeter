import 'package:demeter/services/device_name.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, String> secure;
  final uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  setUp(() {
    secure = {};
    FlutterSecureStorage.setMockInitialValues(secure);
    DeviceName.resetForTest();
  });

  test('la primera vez crea android:<uuid v4> y lo guarda', () async {
    final name = await DeviceName.get();

    expect(name, startsWith('android:'));
    expect(uuidV4.hasMatch(name.substring('android:'.length)), isTrue);
    expect(secure['device_name'], name);
  });

  test('en iOS el prefijo es ios:', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(await DeviceName.get(), startsWith('ios:'));
  });

  test('es el mismo en cada login y tras reiniciar la app', () async {
    final first = await DeviceName.get();
    expect(await DeviceName.get(), first);

    DeviceName.resetForTest(); // Como un proceso nuevo: lo lee del almacén.
    expect(await DeviceName.get(), first);
  });

  test('dos logins a la vez comparten un solo nombre', () async {
    final names = await Future.wait([DeviceName.get(), DeviceName.get()]);

    expect(names[0], names[1]);
    expect(secure['device_name'], names[0]);
  });

  test('cada instalación tiene uno distinto', () async {
    final first = await DeviceName.get();

    FlutterSecureStorage.setMockInitialValues({}); // Reinstalación.
    DeviceName.resetForTest();

    expect(await DeviceName.get(), isNot(first));
  });

  test('si el almacén falla, el error no queda guardado', () async {
    // Un mapa constante hace fallar la escritura.
    FlutterSecureStorage.setMockInitialValues(const {});
    await expectLater(DeviceName.get(), throwsUnsupportedError);

    FlutterSecureStorage.setMockInitialValues({});
    expect(await DeviceName.get(), startsWith('android:'));
  });
}

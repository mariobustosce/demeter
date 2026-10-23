import 'package:demeter/services/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Map<String, String> secure;

  setUp(() {
    secure = {};
    FlutterSecureStorage.setMockInitialValues(secure);
    SharedPreferences.setMockInitialValues({});
  });

  Future<String?> legacyToken() async =>
      (await SharedPreferences.getInstance()).getString('sanctum_token');

  test('guarda, lee y borra en el almacén seguro, no en prefs', () async {
    final store = TokenStore();

    await store.write('tok-1');
    expect(await store.read(), 'tok-1');
    expect(secure['sanctum_token'], 'tok-1');
    expect(await legacyToken(), isNull);

    await store.clear();
    expect(await store.read(), isNull);
  });

  test('migra el token viejo y borra la clave en texto plano', () async {
    SharedPreferences.setMockInitialValues({'sanctum_token': 'viejo'});

    await TokenStore().migrateLegacy();

    expect(await TokenStore().read(), 'viejo');
    expect(await legacyToken(), isNull);
  });

  test('no pisa un token seguro más nuevo', () async {
    secure['sanctum_token'] = 'nuevo';
    SharedPreferences.setMockInitialValues({'sanctum_token': 'viejo'});

    await TokenStore().migrateLegacy();

    expect(await TokenStore().read(), 'nuevo');
    expect(await legacyToken(), isNull);
  });

  test('una clave vieja vacía solo se borra', () async {
    SharedPreferences.setMockInitialValues({'sanctum_token': ''});

    await TokenStore().migrateLegacy();

    expect(await TokenStore().read(), isNull);
    expect(await legacyToken(), isNull);
  });

  test('si el almacén seguro falla, la clave vieja queda para reintentar',
      () async {
    // Un mapa constante hace fallar la escritura.
    FlutterSecureStorage.setMockInitialValues(const {});
    SharedPreferences.setMockInitialValues({'sanctum_token': 'viejo'});

    await TokenStore().migrateLegacy();

    expect(await legacyToken(), 'viejo');
  });
}

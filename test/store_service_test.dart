import 'dart:convert';

import 'package:demeter/services/api_client.dart';
import 'package:demeter/services/store_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes/store_json.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

void main() {
  late List<http.Request> requests;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'sanctum_token': 'tok-1'});
    requests = [];
  });

  StoreService serviceWith(Object body) => StoreService(
        api: ApiClient(
          baseUrl: 'https://windowsdemeter.com/api',
          httpClient: MockClient((req) async {
            requests.add(req);
            return http.Response(jsonEncode(body), 200, headers: _json);
          }),
        ),
      );

  test('pide los paquetes de Android, con la cuenta ofuscada', () async {
    final catalog = await serviceWith(storeCatalogJson()).catalog();

    final request = requests.single;
    expect(request.url.path, '/api/store/packages');
    expect(request.url.queryParameters, {'plataforma': 'android'});
    expect(catalog.accountId, kObfuscatedAccountId);
    expect([for (final p in catalog.packages) p.productId], ['polvo_50', 'polvo_100']);
    expect(catalog.packages[1].coins, 100);
    expect(catalog.packages[1].highlight, isTrue);
  });

  test('descarta los paquetes que no se venden en Play', () async {
    final catalog = await serviceWith(storeCatalogJson(
      accountId: '',
      packages: [
        storePackageJson(1, ''),
        {...storePackageJson(2, 'x')}..remove('google_play_product_id'),
        storePackageJson(3, 'polvo_1000', coins: 1000),
      ],
    )).catalog();

    expect(catalog.accountId, isNull);
    expect([for (final p in catalog.packages) p.productId], ['polvo_1000']);
  });
}

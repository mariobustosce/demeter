/// Una cuenta ofuscada de prueba (64 hex, como la del servidor).
const String kObfuscatedAccountId =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

/// Un paquete como lo manda `GET /api/store/packages?plataforma=android`.
Map<String, Object?> storePackageJson(
  int id,
  String productId, {
  int coins = 100,
  bool highlight = false,
}) =>
    {
      'id': id,
      'name': 'Pack $coins',
      'coins': coins,
      'price_clp': 3490,
      'currency': 'CLP',
      'icon': 'star',
      'color': 'purple',
      'description': 'Polvo para el oráculo',
      'highlight': highlight,
      'google_play_product_id': productId,
    };

Map<String, Object?> storeCatalogJson({
  String? accountId = kObfuscatedAccountId,
  List<Map<String, Object?>>? packages,
}) =>
    {
      'status': 'success',
      'obfuscated_account_id': accountId,
      'data': packages ??
          [
            storePackageJson(1, 'polvo_50', coins: 50),
            storePackageJson(2, 'polvo_100', highlight: true),
          ],
    };

/// Un `app_account_token` de prueba (UUID en minúsculas, como el del servidor).
const String kAppAccountToken = '0b9e6f3a-1c2d-4e5f-8a7b-9c0d1e2f3a4b';

/// Lo mismo que [storeCatalogJson], como lo manda `?plataforma=ios`.
Map<String, Object?> storeCatalogJsonIos({
  String? accountToken = kAppAccountToken,
  List<Map<String, Object?>>? packages,
}) =>
    {
      'status': 'success',
      'app_account_token': accountToken,
      'data': [
        for (final p in packages ??
            [
              storePackageJson(1, 'polvo_50', coins: 50),
              storePackageJson(2, 'polvo_100', highlight: true),
            ])
          {
            for (final e in p.entries)
              if (e.key != 'google_play_product_id') e.key: e.value,
            'app_store_product_id': p['google_play_product_id'],
          },
      ],
    };

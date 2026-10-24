import '../models/store_package.dart';
import 'api_client.dart';

/// Los paquetes de polvo estelar que se venden en Google Play.
class StoreService {
  StoreService({ApiClient? api}) : _apiOverride = api;

  final ApiClient? _apiOverride;
  ApiClient get _api => _apiOverride ?? ApiClient.instance;

  /// Sin `plataforma=android` el servidor manda los de Mercado Pago.
  Future<StoreCatalog> catalog() async {
    final body = jsonMap(
      await _api.get('/store/packages', query: {'plataforma': 'android'}),
    );
    final accountId = body['obfuscated_account_id']?.toString() ?? '';
    final raw = body['data'];
    return StoreCatalog(
      accountId: accountId.isEmpty ? null : accountId,
      packages: [
        if (raw is List)
          for (final item in raw) ?StorePackage.fromJson(item),
      ],
    );
  }
}

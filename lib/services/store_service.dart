import '../models/store_package.dart';
import 'api_client.dart';
import 'tienda_plataforma.dart';

/// Los paquetes de polvo estelar que se venden en la tienda del teléfono.
class StoreService {
  StoreService({ApiClient? api, TiendaPlataforma? plataforma})
      : _apiOverride = api,
        _plataforma = plataforma ?? TiendaPlataforma.actual();

  final ApiClient? _apiOverride;
  ApiClient get _api => _apiOverride ?? ApiClient.instance;
  final TiendaPlataforma _plataforma;

  /// Sin `plataforma` el servidor manda los de Mercado Pago.
  Future<StoreCatalog> catalog() async {
    final body = jsonMap(
      await _api.get('/store/packages', query: {'plataforma': _plataforma.plataforma}),
    );
    final accountId = body[_plataforma.campoCuenta]?.toString() ?? '';
    final raw = body['data'];
    return StoreCatalog(
      accountId: accountId.isEmpty ? null : accountId,
      packages: [
        if (raw is List)
          for (final item in raw)
            ?StorePackage.fromJson(item, campoProducto: _plataforma.campoProducto),
      ],
    );
  }
}

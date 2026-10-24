import '../models/favorite.dart';
import 'api_client.dart';

/// Lugares favoritos del usuario (`/api/favoritos`).
class FavoritesService {
  ApiClient get _api => ApiClient.instance;

  /// Del más antiguo al más nuevo, como los manda el servidor.
  Future<List<Favorite>> list() async {
    final body = jsonMap(await _api.get('/favoritos'));
    final raw = body['favoritos'];
    if (raw is! List) return const [];
    return [
      for (final item in raw) ?Favorite.fromJson(item),
    ];
  }
}

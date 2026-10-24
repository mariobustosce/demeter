import '../models/favorite.dart';
import 'api_client.dart';
import 'location_service.dart';

/// Lugares favoritos del usuario (`/api/favoritos`) y el paisaje de cada uno.
class FavoritesService {
  FavoritesService({ApiClient? api}) : _apiOverride = api;

  final ApiClient? _apiOverride;
  ApiClient get _api => _apiOverride ?? ApiClient.instance;

  /// Del más antiguo al más nuevo, como los manda el servidor.
  Future<List<Favorite>> list() async {
    final body = jsonMap(await _api.get('/favoritos'));
    final raw = body['favoritos'];
    if (raw is! List) return const [];
    return [
      for (final item in raw) ?Favorite.fromJson(item),
    ];
  }

  /// Guarda el lugar con 2 decimales (unos 1 km), los mismos que lleva la URL
  /// de «Mi ubicación». Sin título, el servidor le pone el nombre del lugar.
  /// [existing] es `true` si ese punto ya estaba guardado. El tope de
  /// favoritos llega como [ValidationException] con el mensaje del servidor.
  Future<({Favorite favorite, bool existing})> save(
    RoundedLocation location,
  ) async {
    final body = jsonMap(await _api.post(
      '/favoritos',
      body: {'lat': location.lat, 'lon': location.lon},
    ));
    return (favorite: _favorite(body), existing: body['existente'] == true);
  }

  Future<Favorite> rename(int id, String title) async {
    final body = jsonMap(await _api.patch('/favoritos/$id', body: {'titulo': title}));
    return _favorite(body);
  }

  /// Borra también su fondo animado y el rotativo comprado para él.
  Future<void> delete(int id) => _api.delete('/favoritos/$id');

  /// La clave del paisaje del favorito, o `null` si usa el de siempre.
  Future<String?> landscapeOf(int id) async {
    final body = jsonMap(await _api.get('/favoritos/$id/paisaje'));
    return _key(body['paisaje']);
  }

  /// Con [key] `null` vuelve al de siempre. Devuelve la clave que quedó.
  Future<String?> setLandscape(int id, String? key) async {
    final body = jsonMap(await _api.patch(
      '/favoritos/$id/paisaje',
      body: {'paisaje': key},
    ));
    return _key(body['paisaje']);
  }

  /// Lo que se le muestra al usuario. El `message` de un 404 o un 403 no es
  /// para él: el favorito se borró en otro lado o no es suyo.
  static String messageFor(ApiException error) => switch (error.statusCode) {
        404 || 403 => 'Ese lugar ya no está en tus favoritos.',
        _ => error.message,
      };

  static Favorite _favorite(Map<String, dynamic> body) =>
      Favorite.fromJson(body['favorito']) ??
      (throw const ApiException('Respuesta inesperada del servidor.'));

  static String? _key(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}

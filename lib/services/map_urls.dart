import '../config/app_config.dart';
import '../models/map_mode.dart';
import 'location_service.dart';

/// URLs de las páginas kiosk del mapa y qué puede abrir el WebView.
///
/// El refresco de la página borra la query salvo `lat`, `lon`, `ratio` y
/// `paisaje`: por eso el token, el modo y el favorito van en el path.
class MapUrls {
  MapUrls._();

  static const String _mapPath = '/app/mapa/';

  /// El mapa de quien no tiene sesión. Sin [location], el servidor usa la
  /// cookie, la IP o la ubicación por defecto.
  static Uri guest(
    MapMode mode, {
    RoundedLocation? location,
    required double ratio,
    String? webBase,
  }) =>
      Uri.parse('${webBase ?? kWebBase}$_mapPath${mode.name}').replace(
        queryParameters: _query(ratio, location),
      );

  /// El mapa del usuario: [viewBase] es el `base_url` de su token de vista.
  /// Con [favoriteId] se ve ese favorito y [location] se ignora: sus
  /// coordenadas nunca viajan en la URL.
  static Uri user(
    String viewBase,
    MapMode mode, {
    int? favoriteId,
    RoundedLocation? location,
    required double ratio,
  }) {
    final path = favoriteId == null
        ? '$viewBase/${mode.name}'
        : '$viewBase/${mode.name}/f/$favoriteId';
    return Uri.parse(path).replace(
      queryParameters: _query(ratio, favoriteId == null ? location : null),
    );
  }

  static Map<String, String> _query(double ratio, RoundedLocation? location) => {
        if (location != null) 'lat': location.latParam,
        if (location != null) 'lon': location.lonParam,
        'ratio': clampRatio(ratio).toStringAsFixed(2),
      };

  /// Alto ÷ ancho dentro del rango que acepta el servidor.
  static double clampRatio(double ratio) =>
      ratio.isFinite ? ratio.clamp(kMapRatioMin, kMapRatioMax) : kMapRatioMin;

  /// Lo único que el WebView puede abrir: `/app/mapa/…` del servidor, por el
  /// mismo esquema y puerto.
  static bool isMapPage(Uri uri, {String? webBase}) {
    final base = Uri.parse(webBase ?? kWebBase);
    return _sameOrigin(uri, base) &&
        uri.path.startsWith(_mapPath) &&
        !uri.pathSegments.any((s) => s == '..' || s == '.');
  }

  /// Otras páginas del sitio: se abren en el navegador. Lo de otros sitios se
  /// bloquea.
  static bool opensInBrowser(Uri uri, {String? webBase}) =>
      uri.scheme == 'https' &&
      _sameOrigin(uri, Uri.parse(webBase ?? kWebBase)) &&
      !isMapPage(uri, webBase: webBase);

  static bool _sameOrigin(Uri uri, Uri base) =>
      uri.scheme == base.scheme &&
      uri.host == base.host &&
      uri.port == base.port &&
      uri.userInfo.isEmpty;

  /// La petición con la que la página se refresca sola cada 5 minutos.
  static bool isRefresh(Uri uri) => uri.queryParameters.containsKey('fragmento');
}

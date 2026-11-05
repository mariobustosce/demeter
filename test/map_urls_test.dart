import 'package:demeter/models/map_mode.dart';
import 'package:demeter/services/location_service.dart';
import 'package:demeter/services/map_urls.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const web = 'https://windowsdemeter.com';
  const view = '$web/app/mapa/t/abcdefghijABCDEFGHIJ0123456789abcdefghij';

  group('RoundedLocation', () {
    test('redondea a 2 decimales', () {
      final location = RoundedLocation(-33.52274, -70.59836);
      expect(location.latParam, '-33.52');
      expect(location.lonParam, '-70.60');
    });
  });

  group('invitado', () {
    test('con ubicación: lat y lon con 2 decimales, y ratio', () {
      final uri = MapUrls.guest(
        MapMode.profesional,
        location: RoundedLocation(-33.456789, -70.648123),
        ratio: 2.1666,
        webBase: web,
      );
      expect(uri.toString(),
          '$web/app/mapa/profesional?lat=-33.46&lon=-70.65&ratio=2.17');
    });

    test('sin ubicación: solo ratio, para que el servidor use la IP', () {
      final uri = MapUrls.guest(MapMode.basico, ratio: 1.8, webBase: web);
      expect(uri.queryParameters, {'ratio': '1.80'});
    });

    test('el ratio se acota a 1.5–2.4', () {
      expect(MapUrls.guest(MapMode.basico, ratio: 3, webBase: web)
          .queryParameters['ratio'], '2.40');
      expect(MapUrls.guest(MapMode.basico, ratio: 0.5, webBase: web)
          .queryParameters['ratio'], '1.50');
      expect(MapUrls.clampRatio(double.nan), 1.5);
    });
  });

  group('usuario', () {
    test('en su ubicación: el token va en el path y lat/lon en la query', () {
      final uri = MapUrls.user(
        view,
        MapMode.astronomico,
        location: RoundedLocation(-33.45, -70.66),
        ratio: 2,
      );
      expect(uri.path, endsWith('/astronomico'));
      expect(uri.queryParameters, {'lat': '-33.45', 'lon': '-70.66', 'ratio': '2.00'});
    });

    test('en un favorito: sin coordenadas aunque se pasen', () {
      final uri = MapUrls.user(
        view,
        MapMode.basico,
        favoriteId: 12,
        location: RoundedLocation(-33.45, -70.66),
        ratio: 2,
      );
      expect(uri.toString(), '$view/basico/f/12?ratio=2.00');
    });

    test('con otro momento: momento en segundos, también antes de 1970', () {
      final uri = MapUrls.user(
        view,
        MapMode.basico,
        location: RoundedLocation(-33.45, -70.66),
        moment: 1617809580,
        ratio: 2,
      );
      expect(uri.queryParameters['momento'], '1617809580');
      expect(
        MapUrls.user(view, MapMode.basico, moment: -1000000000, ratio: 2).queryParameters['momento'],
        '-1000000000',
      );
    });
  });

  group('qué abre el WebView', () {
    bool map(String url) => MapUrls.isMapPage(Uri.parse(url), webBase: web);
    bool browser(String url) =>
        MapUrls.opensInBrowser(Uri.parse(url), webBase: web);

    test('el mapa del servidor, también con token y su refresco', () {
      expect(map('$web/app/mapa/basico?ratio=2'), isTrue);
      expect(map('$view/basico/f/3?ratio=2&fragmento=1'), isTrue);
      expect(map('https://WindowsDemeter.com/app/mapa/basico'), isTrue);
    });

    test('nada fuera de /app/mapa/ ni de otro origen', () {
      expect(map('http://windowsdemeter.com/app/mapa/basico'), isFalse);
      expect(map('https://windowsdemeter.com:8443/app/mapa/basico'), isFalse);
      expect(map('https://windowsdemeter.com.evil.test/app/mapa/basico'), isFalse);
      expect(map('https://evil.test/app/mapa/basico'), isFalse);
      expect(map('https://user@windowsdemeter.com/app/mapa/basico'), isFalse);
      expect(map('$web/app/mapax'), isFalse);
      expect(map('$web/login'), isFalse);
      expect(map('$web/app/mapa/../login'), isFalse);
      expect(map('$web/app/mapa/%2e%2e/login'), isFalse);
      expect(map('file:///data/data/x'), isFalse);
      expect(map('javascript:alert(1)'), isFalse);
    });

    test('otras páginas del sitio van al navegador; las de fuera, no', () {
      expect(browser('$web/blog'), isTrue);
      expect(browser('$web/app/mapa/basico'), isFalse);
      expect(browser('https://evil.test/'), isFalse);
      expect(browser('http://windowsdemeter.com/blog'), isFalse);
      expect(browser('intent://scan#Intent;end'), isFalse);
    });

    test('el refresco se reconoce por ?fragmento', () {
      expect(MapUrls.isRefresh(Uri.parse('$view/basico?fragmento=1')), isTrue);
      expect(MapUrls.isRefresh(Uri.parse('$view/basico?ratio=2')), isFalse);
    });
  });
}

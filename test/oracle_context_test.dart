import 'package:demeter/services/sky_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Lo que pasa la lista blanca del servidor (ContextoConsulta::oraculo).
  const whitelist = {
    'momento', 'hemisferio', 'estacion', 'sol', 'luna', 'planetas_visibles',
    'casa_dominante', 'zodiaco_dominante', 'todas_las_casas', 'zodiaco_completo',
  };

  final mapApiMobile = <String, dynamic>{
    'timestamp': 1792771200,
    'lat': -33.4489,
    'lon': -70.6693,
    'location': 'La Florida',
    'config': {'lat': -33.4489, 'lon': -70.6693},
    'weather': {'location_name': 'La Florida', 'current': {'temperature': 18}},
    'hemisferio': 'Sur',
    'arcos': {'season': 'primavera'},
    'solar': {
      'position': {'altitude': 32.5, 'constellation': 'Libra'},
    },
    'lunar': {'phase_name': 'Cuarto creciente', 'illumination_percent': 48.6},
    'planetas': {
      'visibles': {
        'venus': {'visible': true, 'altitude': 12},
        'marte': {'visible': false, 'altitude': -5},
        'jupiter': {'altitude': 3},
      },
    },
    'zodiaco': {
      'potencias': {'aries': 2, 'libra': 9, 'tauro': 4},
      'horarios': {'libra': {'nombre': 'Libra'}},
    },
    'casas': {'dominant_house': 'Casa VII'},
  };

  test('arma las claves de la web desde map-api-mobile', () {
    final context = oracleContextFrom(mapApiMobile);

    expect(context, {
      'momento': 1792771200,
      'hemisferio': 'Sur',
      'estacion': 'primavera',
      'sol': {'visible': true, 'constelacion': 'Libra'},
      'luna': {'fase': 'Cuarto creciente', 'iluminacion': 49},
      'planetas_visibles': ['Venus', 'Jupiter'],
      'zodiaco_dominante': 'Libra',
      'casa_dominante': 'Casa VII',
    });
  });

  test('sin coordenadas, clima ni lugar, y dentro de la lista blanca', () {
    final context = oracleContextFrom(mapApiMobile);

    expect(whitelist.containsAll(context.keys), isTrue);
    expect(context.length, lessThanOrEqualTo(20));
    final text = context.toString();
    expect(text, isNot(contains('-33.4')));
    expect(text, isNot(contains('La Florida')));
  });

  test('con datos faltantes o de otro tipo no falla', () {
    expect(oracleContextFrom(const {}), {
      'sol': {'visible': false, 'constelacion': null},
      'luna': {'fase': null, 'iluminacion': 0},
      'planetas_visibles': <String>[],
    });
    expect(
      () => oracleContextFrom({'solar': 'x', 'planetas': [], 'zodiaco': 3}),
      returnsNormally,
    );
  });
}

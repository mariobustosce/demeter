/// Un aviso de `GET /api/avisos`, con lo que el test no fija a mano.
Map<String, Object?> avisoJson(
  String id, {
  String tipo = 'lluvia',
  String titulo = 'Lluvia fuerte mañana',
  String texto = 'Se esperan 30 mm.',
  String lugar = 'Casa',
  bool leido = false,
  String? url,
  String? fuente,
}) =>
    {
      'id': id,
      'tipo': tipo,
      'titulo': titulo,
      'texto': texto,
      'lugar': lugar,
      'lat': lugar.isEmpty ? null : -33.45,
      'lon': lugar.isEmpty ? null : -70.66,
      'fecha_objetivo': '2026-10-25',
      'expira_en': '2026-10-26T02:59:59-03:00',
      'url': url,
      'fuente': fuente,
      'leido': leido,
      'creado_en': '2026-10-24T18:30:00-03:00',
    };

/// `GET /api/avisos/preferencias` con las tres secciones de la web.
Map<String, Object?> preferenciasJson({
  bool tieneFavoritos = true,
  Set<String> activas = const {},
}) {
  Map<String, Object?> aviso(String tipo, String etiqueta) => {
        'tipo': tipo,
        'etiqueta': etiqueta,
        'descripcion': 'Descripción de $etiqueta',
        'activo': activas.contains(tipo),
      };
  return {
    'success': true,
    'tiene_favoritos': tieneFavoritos,
    'suscripciones': {for (final t in ['lluvia', 'helada', 'sismo', 'luna']) t: activas.contains(t)},
    'secciones': [
      {
        'clave': 'clima',
        'titulo': 'Alertas climáticas',
        'texto': 'Revisamos el pronóstico de mañana.',
        'avisos': [aviso('lluvia', 'Lluvia fuerte'), aviso('helada', 'Helada')],
      },
      {
        'clave': 'catastrofes',
        'titulo': 'Catástrofes en curso',
        'texto': 'Viene de GDACS: es automático e indicativo, y no reemplaza las '
            'alertas de las autoridades locales.',
        'avisos': [aviso('sismo', 'Sismo')],
      },
      {
        'clave': 'astrologicos',
        'titulo': 'Avisos astrológicos',
        'texto': 'Lunas llenas y nuevas.',
        'avisos': [aviso('luna', 'Luna llena y nueva')],
      },
    ],
  };
}

import 'package:flutter/foundation.dart';

/// Un aviso de `GET /api/avisos`: clima, catástrofe o cielo sobre un favorito.
/// Las coordenadas no se leen: la app no las usa.
@immutable
class Aviso {
  const Aviso({
    required this.id,
    required this.type,
    required this.title,
    this.text = '',
    this.place = '',
    this.source,
    this.sourceUrl,
    this.read = false,
    this.createdAt,
    this.targetDate,
  });

  /// El uuid: el mismo `aviso_id` del push.
  final String id;

  /// `lluvia`, `sismo`, `luna`… o `prueba`.
  final String type;
  final String title;
  final String text;

  /// El favorito. Vacío en los que no son de un lugar (cielo y `prueba`).
  final String place;

  /// Quién lo publica (GDACS…) y su enlace, que solo se acepta si es https.
  final String? source;
  final Uri? sourceUrl;

  final bool read;
  final DateTime? createdAt;

  /// El día al que se refiere (el pronóstico de mañana, la luna llena…).
  final DateTime? targetDate;

  Aviso copyWith({bool? read}) => Aviso(
        id: id,
        type: type,
        title: title,
        text: text,
        place: place,
        source: source,
        sourceUrl: sourceUrl,
        read: read ?? this.read,
        createdAt: createdAt,
        targetDate: targetDate,
      );

  /// `null` si le falta el id.
  static Aviso? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final url = Uri.tryParse('${json['url'] ?? ''}');
    final source = '${json['fuente'] ?? ''}'.trim();
    return Aviso(
      id: id,
      type: '${json['tipo'] ?? ''}',
      title: _title(json['titulo']),
      text: '${json['texto'] ?? ''}'.trim(),
      place: '${json['lugar'] ?? ''}'.trim(),
      source: source.isEmpty ? null : source,
      sourceUrl: url != null && url.isScheme('https') && url.host.isNotEmpty ? url : null,
      read: json['leido'] == true,
      createdAt: _instant(json['creado_en']),
      targetDate: _day(json['fecha_objetivo']),
    );
  }

  /// Lo que trae el `data` del push: `{aviso_id, tipo, titulo, texto}`, sin
  /// lugar ni coordenadas. `null` si no es un aviso.
  static Aviso? fromPush(Map<String, dynamic> data) {
    final id = data['aviso_id'];
    if (id is! String || id.isEmpty) return null;
    return Aviso(
      id: id,
      type: '${data['tipo'] ?? ''}',
      title: _title(data['titulo']),
      text: '${data['texto'] ?? ''}'.trim(),
    );
  }

  static String _title(Object? value) {
    final title = '${value ?? ''}'.trim();
    return title.isEmpty ? 'Aviso' : title;
  }

  static DateTime? _instant(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  // Un día del lugar (`2026-10-25`): sin pasarlo a la hora del teléfono, que
  // podría cambiarlo de fecha.
  static DateTime? _day(Object? value) {
    final date = value is String ? DateTime.tryParse(value) : null;
    return date == null ? null : DateTime(date.year, date.month, date.day);
  }
}

/// El icono de cada tipo, el mismo de la web (`BandejaAvisos::icono`).
String avisoIcon(String type) => switch (type) {
      'lluvia' => '🌧️',
      'helada' => '❄️',
      'ciclon' => '🌀',
      'sismo' => '📳',
      'inundacion' => '🌊',
      'volcan' => '🌋',
      'incendio' => '🔥',
      'luna' => '🌕',
      'eclipse_lunar' => '🌘',
      'eclipse_solar' => '🌒',
      'retrogrado' => '🔁',
      'ingreso' => '✨',
      _ => '⚠️',
    };

/// Los que vienen de GDACS: siempre llevan su aviso legal. Si el servidor
/// suma otro, llega en la sección `catastrofes` de las preferencias.
const Set<String> kCatastropheTypes = {
  'ciclon',
  'sismo',
  'inundacion',
  'volcan',
  'incendio',
};

/// Va siempre con las catástrofes: la información de GDACS es indicativa.
const String kGdacsDisclaimer =
    'Información automática e indicativa de GDACS (ONU y Comisión Europea): '
    'no reemplaza las alertas de las autoridades locales.';

/// Una alerta a la que el usuario se puede suscribir.
@immutable
class AlertType {
  const AlertType({
    required this.type,
    required this.label,
    this.description = '',
    this.active = false,
  });

  final String type;
  final String label;
  final String description;
  final bool active;

  AlertType copyWith({bool? active}) => AlertType(
        type: type,
        label: label,
        description: description,
        active: active ?? this.active,
      );

  static AlertType? fromJson(Object? json) {
    if (json is! Map) return null;
    final type = json['tipo'];
    if (type is! String || type.isEmpty) return null;
    final label = '${json['etiqueta'] ?? ''}'.trim();
    return AlertType(
      type: type,
      label: label.isEmpty ? type : label,
      description: '${json['descripcion'] ?? ''}'.trim(),
      active: json['activo'] == true,
    );
  }
}

/// Una de las tres familias: `clima`, `catastrofes` o `astrologicos`.
@immutable
class AlertSection {
  const AlertSection({
    required this.key,
    required this.title,
    this.text = '',
    this.alerts = const [],
  });

  final String key;

  /// El nombre de la web: «Alertas climáticas», «Catástrofes en curso»…
  final String title;

  /// La de catástrofes trae el aviso legal de GDACS.
  final String text;
  final List<AlertType> alerts;

  bool get isCatastrophes => key == 'catastrofes';

  int get activeCount => alerts.where((a) => a.active).length;

  AlertSection withActive(String type, bool active) => AlertSection(
        key: key,
        title: title,
        text: text,
        alerts: [
          for (final a in alerts) a.type == type ? a.copyWith(active: active) : a,
        ],
      );

  static AlertSection? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['clave'];
    if (key is! String || key.isEmpty) return null;
    final raw = json['avisos'];
    final title = '${json['titulo'] ?? ''}'.trim();
    return AlertSection(
      key: key,
      title: title.isEmpty ? key : title,
      text: '${json['texto'] ?? ''}'.trim(),
      alerts: [
        if (raw is List)
          for (final item in raw) ?AlertType.fromJson(item),
      ],
    );
  }
}

/// `GET/PUT /api/avisos/preferencias`.
@immutable
class AlertPreferences {
  const AlertPreferences({required this.hasFavorites, required this.sections});

  /// Sin favoritos se puede suscribir, pero no llega ningún aviso.
  final bool hasFavorites;

  /// Siempre en el orden de la web.
  final List<AlertSection> sections;

  bool get anyActive => sections.any((s) => s.activeCount > 0);

  /// Los tipos de GDACS: los del aviso legal.
  Set<String> get catastropheTypes => {
        ...kCatastropheTypes,
        for (final s in sections)
          if (s.isCatastrophes)
            for (final a in s.alerts) a.type,
      };

  /// Como quedan si el servidor acepta el cambio.
  AlertPreferences withActive(String type, bool active) => AlertPreferences(
        hasFavorites: hasFavorites,
        sections: [for (final s in sections) s.withActive(type, active)],
      );

  static AlertPreferences fromJson(Map<String, dynamic> json) {
    final raw = json['secciones'];
    return AlertPreferences(
      hasFavorites: json['tiene_favoritos'] == true,
      sections: [
        if (raw is List)
          for (final item in raw) ?AlertSection.fromJson(item),
      ],
    );
  }
}

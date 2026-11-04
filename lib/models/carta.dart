import 'package:flutter/foundation.dart';

/// Un firmamento (carta astral) del listado (`GET /api/user/charts`).
///
/// Lleva los datos de nacimiento del propio usuario: no se registran ni se
/// mandan a ningún otro sitio.
@immutable
class Carta {
  const Carta({
    required this.id,
    required this.titulo,
    this.birthDate = '',
    this.birthTime = '',
    this.lat,
    this.lon,
    this.timezone,
    this.sunDegree,
    this.tzRevisar = false,
  });

  final int id;
  final String titulo;

  /// `AAAA-MM-DD` (el servidor lo manda con la hora en cero).
  final String birthDate;

  /// `HH:MM`.
  final String birthTime;
  final double? lat;
  final double? lon;

  /// Tal como se guardó: un nombre IANA o, en las cartas viejas, un desfase.
  final String? timezone;
  final double? sunDegree;

  /// Guardada con una zona que no es la del lugar y con otro desfase ese día.
  final bool tzRevisar;

  /// Índice del signo solar (0 = Aries), o `null` sin grado.
  int? get sunSign =>
      sunDegree == null ? null : (sunDegree! % 360 ~/ 30).clamp(0, 11);

  /// `null` si le falta el id.
  static Carta? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _toInt(json['id']);
    if (id == null) return null;
    final titulo = json['titulo'] ?? json['title'];
    return Carta(
      id: id,
      titulo: titulo is String ? titulo : '',
      birthDate: _fecha(json['birth_date']),
      birthTime: _hora(json['birth_time']),
      lat: _toDouble(json['birth_lat']),
      lon: _toDouble(json['birth_lon']),
      timezone: json['timezone'] is String ? json['timezone'] as String : null,
      sunDegree: _toDouble(json['sun_degree']),
      tzRevisar: json['tz_revisar'] == true,
    );
  }

  static String _fecha(Object? v) =>
      v is String ? v.split('T').first.split(' ').first : '';

  static String _hora(Object? v) {
    if (v is! String) return '';
    final partes = v.split(':');
    return partes.length >= 2 ? '${partes[0]}:${partes[1]}' : v;
  }
}

/// La zona IANA de un lugar y el desfase que regía en una fecha
/// (`GET /api/user/zona`).
@immutable
class ZonaLugar {
  const ZonaLugar({
    required this.timezone,
    required this.rotulo,
    this.desfase = 0,
    this.horarioVerano = false,
  });

  /// Nombre IANA, p. ej. `America/Santiago`.
  final String timezone;

  /// Desfase listo para mostrar, p. ej. `UTC−04:00`.
  final String rotulo;

  /// En segundos.
  final int desfase;
  final bool horarioVerano;

  static ZonaLugar? fromJson(Object? json) {
    if (json is! Map) return null;
    final tz = json['timezone'];
    if (tz is! String || tz.isEmpty) return null;
    final rotulo = json['rotulo'];
    return ZonaLugar(
      timezone: tz,
      rotulo: rotulo is String ? rotulo : '',
      desfase: _toInt(json['desfase']) ?? 0,
      horarioVerano: json['horario_verano'] == true,
    );
  }
}

int? _toInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

// El servidor manda las coordenadas y los grados como textos decimales.
double? _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

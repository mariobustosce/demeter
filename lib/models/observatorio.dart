import 'package:flutter/foundation.dart';

/// Un Estudio del cielo: la suscripción anual de un favorito.
@immutable
class Estudio {
  const Estudio({
    required this.id,
    required this.titulo,
    this.activo = false,
    this.desde,
    this.expira,
    this.renovable = false,
    this.capturas = 0,
    this.primeraCaptura,
    this.ultimaCaptura,
  });

  final int id;
  final String titulo;

  /// Vencido: en pausa, pero se lee y se exporta.
  final bool activo;
  final DateTime? desde;
  final DateTime? expira;

  /// Desde 30 días antes de vencer; nunca si quedó huérfano.
  final bool renovable;
  final int capturas;

  /// Solo en `GET /api/estudios/{id}`: `AAAA-MM-DD`.
  final String? primeraCaptura;
  final String? ultimaCaptura;

  static Estudio? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _i(json['id']);
    if (id == null) return null;
    return Estudio(
      id: id,
      titulo: json['titulo'] is String ? json['titulo'] as String : '',
      activo: json['activo'] == true,
      desde: _fecha(json['desde']),
      expira: _fecha(json['expira']),
      renovable: json['renovable'] == true,
      capturas: _i(json['capturas']) ?? 0,
      primeraCaptura: json['primera_captura'] is String ? json['primera_captura'] as String : null,
      ultimaCaptura: json['ultima_captura'] is String ? json['ultima_captura'] as String : null,
    );
  }
}

/// El clima de ahora de un favorito, para su tarjeta.
@immutable
class ClimaActual {
  const ClimaActual({
    this.temperatura,
    this.codigoWmo,
    this.esDeDia = true,
    this.vientoKmh,
    this.humedadPct,
    this.precipitacionMm,
    this.reserva = false,
  });

  final double? temperatura;
  final int? codigoWmo;
  final bool esDeDia;
  final double? vientoKmh;
  final double? humedadPct;
  final double? precipitacionMm;

  /// No es de ahora: el último clima conocido.
  final bool reserva;

  static ClimaActual? fromJson(Object? json) {
    if (json is! Map) return null;
    return ClimaActual(
      temperatura: _d(json['temperatura']),
      codigoWmo: _i(json['codigo_wmo']),
      esDeDia: json['es_de_dia'] != false,
      vientoKmh: _d(json['viento_kmh']),
      humedadPct: _d(json['humedad_pct']),
      precipitacionMm: _d(json['precipitacion_mm']),
      reserva: json['reserva'] == true,
    );
  }
}

/// Una tarjeta de Cielos: un favorito con su clima y su estudio.
@immutable
class LugarCielo {
  const LugarCielo({required this.favoritoId, required this.titulo, this.clima, this.estudio});

  final int favoritoId;
  final String titulo;
  final ClimaActual? clima;
  final Estudio? estudio;

  LugarCielo conEstudio(Estudio e) =>
      LugarCielo(favoritoId: favoritoId, titulo: titulo, clima: clima, estudio: e);

  static LugarCielo? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _i(json['favorito_id']);
    if (id == null) return null;
    return LugarCielo(
      favoritoId: id,
      titulo: json['titulo'] is String ? json['titulo'] as String : '',
      clima: ClimaActual.fromJson(json['clima']),
      estudio: Estudio.fromJson(json['estudio']),
    );
  }
}

/// `GET /api/observatorio`. Los precios salen siempre de aquí; en 0 (cobro
/// apagado o admin) los botones van sin precio.
@immutable
class Observatorio {
  const Observatorio({
    this.precioEstudio = 0,
    this.precioDescarga = 0,
    this.lugares = const [],
    this.huerfanos = const [],
  });

  final int precioEstudio;
  final int precioDescarga;
  final List<LugarCielo> lugares;

  /// Estudios cuyo favorito se borró: se leen y se exportan, no se renuevan.
  final List<Estudio> huerfanos;

  factory Observatorio.fromJson(Object? json) {
    if (json is! Map) return const Observatorio();
    final precios = json['precios'];
    List<dynamic> lista(Object? v) => v is List ? v : const [];
    return Observatorio(
      precioEstudio: precios is Map ? _i(precios['estudio_anual']) ?? 0 : 0,
      precioDescarga: precios is Map ? _i(precios['descarga']) ?? 0 : 0,
      lugares: [for (final l in lista(json['lugares'])) ?LugarCielo.fromJson(l)],
      huerfanos: [for (final e in lista(json['huerfanos'])) ?Estudio.fromJson(e)],
    );
  }
}

DateTime? _fecha(Object? v) => v is String ? DateTime.tryParse(v) : null;

int? _i(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _d(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

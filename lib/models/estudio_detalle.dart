import 'package:flutter/foundation.dart';

/// Un día del resumen (`dias[]`): rango del día y su normal climatológica.
@immutable
class DiaEstudio {
  const DiaEstudio({
    required this.fecha,
    this.n = 0,
    this.tmax,
    this.tmin,
    this.lluvia,
    this.lluviaAprox = false,
    this.normal,
    this.anomalia,
  });

  /// `AAAA-MM-DD`.
  final String fecha;

  /// Turnos con clima ese día.
  final int n;
  final double? tmax;
  final double? tmin;
  final double? lluvia;
  final bool lluviaAprox;

  /// `[tmin, tmax]` normales, o `null` mientras se calcula.
  final (double, double)? normal;

  /// °C sobre (+) o bajo (−) la normal; `null` con menos de 3 turnos.
  final double? anomalia;

  bool get conDatos => tmax != null && tmin != null;

  static DiaEstudio? fromJson(Object? json) {
    if (json is! Map || json['fecha'] is! String) return null;
    final nor = json['normal'];
    final a = nor is List && nor.length == 2 ? _d(nor[0]) : null;
    final b = nor is List && nor.length == 2 ? _d(nor[1]) : null;
    return DiaEstudio(
      fecha: json['fecha'] as String,
      n: _i(json['n']) ?? 0,
      tmax: _d(json['tmax']),
      tmin: _d(json['tmin']),
      lluvia: _d(json['lluvia']),
      lluviaAprox: json['lluvia_aprox'] == true,
      normal: a != null && b != null ? (a, b) : null,
      anomalia: _d(json['anomalia']),
    );
  }
}

/// `GET /api/estudios/{id}/resumen`: los últimos 14 días.
@immutable
class ResumenEstudio {
  const ResumenEstudio({
    this.diasVentana = 14,
    this.hayClima = false,
    this.cobertura,
    this.hayNormal = false,
    this.max,
    this.min,
    this.lluvia,
    this.presion,
    this.resumen = '',
    this.dias = const [],
  });

  final int diasVentana;
  final bool hayClima;
  final ({int n, int total, num pct})? cobertura;
  final bool hayNormal;

  /// `fecha` es una etiqueta lista para mostrar.
  final ({double v, String fecha})? max;
  final ({double v, String fecha})? min;
  final ({double mm, int dias, bool aprox})? lluvia;

  /// `dir`: `sube`, `baja` o `estable`.
  final ({double delta, String dir, double? hpa})? presion;

  /// Texto listo del servidor: se muestra tal cual.
  final String resumen;
  final List<DiaEstudio> dias;

  factory ResumenEstudio.fromJson(Object? json) {
    if (json is! Map) return const ResumenEstudio();
    final cob = json['cobertura'];
    final k = json['kpis'] is Map ? json['kpis'] as Map : const {};
    ({double v, String fecha})? extremo(Object? e) => e is Map && _d(e['v']) != null
        ? (v: _d(e['v'])!, fecha: e['fecha'] is String ? e['fecha'] as String : '')
        : null;
    final ll = k['lluvia'];
    final pr = k['presion'];
    return ResumenEstudio(
      diasVentana: _i(json['dias_ventana']) ?? 14,
      hayClima: json['hay_clima'] == true,
      cobertura: cob is Map
          ? (n: _i(cob['n']) ?? 0, total: _i(cob['total']) ?? 0, pct: (cob['pct'] is num ? cob['pct'] as num : 0))
          : null,
      hayNormal: json['normal'] is Map,
      max: extremo(k['max']),
      min: extremo(k['min']),
      lluvia: ll is Map
          ? (mm: _d(ll['mm']) ?? 0, dias: _i(ll['dias']) ?? 0, aprox: ll['aprox'] == true)
          : null,
      presion: pr is Map && _d(pr['delta']) != null
          ? (delta: _d(pr['delta'])!, dir: pr['dir'] is String ? pr['dir'] as String : 'estable', hpa: _d(pr['hpa']))
          : null,
      resumen: json['resumen'] is String ? json['resumen'] as String : '',
      dias: [
        if (json['dias'] is List)
          for (final d in json['dias'] as List) ?DiaEstudio.fromJson(d),
      ],
    );
  }
}

/// El clima compacto de una captura. Las capturas viejas no traen `st`,
/// `vr` ni `p6`.
@immutable
class ClimaCaptura {
  const ClimaCaptura({
    this.t,
    this.h,
    this.vv,
    this.pp,
    this.pr,
    this.wmo,
    this.dia = true,
    this.uv,
    this.st,
    this.vr,
    this.p6,
  });

  final double? t;
  final double? h;
  final double? vv;
  final double? pp;
  final double? pr;
  final int? wmo;
  final bool dia;

  /// Máximo del día (pronóstico): va una vez por día, nunca de noche.
  final double? uv;
  final double? st;
  final double? vr;
  final double? p6;

  static ClimaCaptura? fromJson(Object? json) {
    if (json is! Map) return null;
    return ClimaCaptura(
      t: _d(json['t']),
      h: _d(json['h']),
      vv: _d(json['vv']),
      pp: _d(json['pp']),
      pr: _d(json['pr']),
      wmo: _i(json['wmo']),
      dia: json['dia'] == null || _i(json['dia']) == 1,
      uv: _d(json['uv']),
      st: _d(json['st']),
      vr: _d(json['vr']),
      p6: _d(json['p6']),
    );
  }
}

/// Un cuerpo en el cielo del lugar en una captura.
@immutable
class AstroCaptura {
  const AstroCaptura({required this.signo, this.altura, this.sobreHorizonte = true, this.retrogrado = false});

  final int signo;
  final double? altura;
  final bool sobreHorizonte;
  final bool retrogrado;
}

@immutable
class Captura {
  const Captura({
    required this.fechaLocal,
    required this.turno,
    this.horaLocal,
    this.estacion,
    this.puntoRocio,
    this.clima,
    this.astros = const {},
  });

  /// `AAAA-MM-DD` en la hora del lugar.
  final String fechaLocal;

  /// `manana`, `dia`, `tarde` o `noche`.
  final String turno;
  final String? horaLocal;

  /// `primavera`, `verano`, `otono`, `invierno` o `null`.
  final String? estacion;
  final double? puntoRocio;

  /// `null`: el turno no tiene clima (se muestra con guiones).
  final ClimaCaptura? clima;

  /// Por clave de cuerpo; Plutón y Quirón solo desde noviembre de 2026.
  final Map<String, AstroCaptura> astros;

  static Captura? fromJson(Object? json) {
    if (json is! Map || json['fecha_local'] is! String) return null;
    final astro = json['astro'];
    final cuerpos = astro is Map && astro['cuerpos'] is Map ? astro['cuerpos'] as Map : const {};
    return Captura(
      fechaLocal: json['fecha_local'] as String,
      turno: json['turno'] is String ? json['turno'] as String : '',
      horaLocal: json['hora_local'] is String ? json['hora_local'] as String : null,
      estacion: json['estacion'] is String ? json['estacion'] as String : null,
      puntoRocio: _d(json['punto_rocio']),
      clima: ClimaCaptura.fromJson(json['clima']),
      astros: {
        for (final e in cuerpos.entries)
          if (e.value is Map && _i(e.value['sg']) != null)
            '${e.key}': AstroCaptura(
              signo: _i(e.value['sg'])!,
              altura: _d(e.value['alt']),
              sobreHorizonte: _i(e.value['sh']) != 0,
              retrogrado: _i(e.value['r']) == 1,
            ),
      },
    );
  }
}

/// Una página de `GET /api/estudios/{id}/capturas`, la más reciente primero.
@immutable
class PaginaCapturas {
  const PaginaCapturas({this.capturas = const [], this.pagina = 1, this.ultimaPagina = 1, this.total = 0});

  final List<Captura> capturas;
  final int pagina;
  final int ultimaPagina;
  final int total;

  bool get hayMas => pagina < ultimaPagina;

  factory PaginaCapturas.fromJson(Object? json) {
    if (json is! Map) return const PaginaCapturas();
    final p = json['paginacion'] is Map ? json['paginacion'] as Map : const {};
    return PaginaCapturas(
      capturas: [
        if (json['capturas'] is List)
          for (final c in json['capturas'] as List) ?Captura.fromJson(c),
      ],
      pagina: _i(p['pagina']) ?? 1,
      ultimaPagina: _i(p['ultima_pagina']) ?? 1,
      total: _i(p['total']) ?? 0,
    );
  }
}

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

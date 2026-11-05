import 'package:flutter/painting.dart';

import '../widgets/firmamento/tablas.dart';
import 'carta.dart';

/// La lectura de un firmamento (`data.firmamento` del detalle). Es lo único
/// que lee la app: `chart_data_json` es interno y puede cambiar de forma.
///
/// Todo es tolerante: un campo ausente deja una lista vacía o `null` (p. ej.
/// Plutón y Quirón faltan fuera de 1800-2200).
class Firmamento {
  Firmamento._({
    required this.motor,
    required this.zona,
    required this.sistemaCasas,
    required this.cuspides,
    required this.ejes,
    required this.cuerpos,
    required this.aspectos,
    required this.figuras,
    required this.reparto,
    required this.luna,
    required this.natal,
    required this.orbes,
    required this.clasesOrbe,
  });

  final int motor;
  final ZonaFirmamento zona;
  final String sistemaCasas;

  /// 12 longitudes, casa I primero (vacía si no vinieron las 12).
  final List<double> cuspides;

  /// `asc`, `mc`, `dsc` e `ic`.
  final Map<String, Eje> ejes;
  final List<Cuerpo> cuerpos;
  final List<Aspecto> aspectos;
  final List<Figura> figuras;
  final Reparto? reparto;
  final LunaFase? luna;
  final Natal natal;
  final List<OrbeFila> orbes;
  final List<String> clasesOrbe;

  double get asc => ejes['asc']?.longitud ?? 0;

  Cuerpo? cuerpo(String clave) {
    for (final c in cuerpos) {
      if (c.clave == clave) return c;
    }
    return null;
  }

  /// Glifo de un cuerpo o de un eje (`asc` → AC).
  String simbolo(String clave) =>
      kEjes[clave]?.sigla ?? cuerpo(clave)?.simbolo ?? clave;

  String nombre(String clave) =>
      kEjes[clave]?.nombre ?? cuerpo(clave)?.nombre ?? clave;

  Color color(String clave) =>
      kEjes[clave]?.color ?? cuerpo(clave)?.color ?? kTextoTenue;

  /// Longitud de un cuerpo o de un eje.
  double? longitud(String clave) =>
      ejes[clave]?.longitud ?? cuerpo(clave)?.longitud;

  static Firmamento? fromJson(Object? json) {
    if (json is! Map) return null;
    final cusp = _lista(json['cuspides']).map(_d).whereType<double>().toList();
    final ejes = <String, Eje>{};
    final rawEjes = json['ejes'];
    if (rawEjes is Map) {
      for (final k in const ['asc', 'mc', 'dsc', 'ic']) {
        final e = Eje.fromJson(rawEjes[k]);
        if (e != null) ejes[k] = e;
      }
    }
    return Firmamento._(
      motor: _i(json['motor']) ?? 0,
      zona: ZonaFirmamento.fromJson(json['zona']),
      sistemaCasas: _s(json['sistema_casas']),
      cuspides: cusp.length == 12 ? cusp : const [],
      ejes: ejes,
      cuerpos: [for (final c in _lista(json['cuerpos'])) ?Cuerpo.fromJson(c)],
      aspectos: [for (final a in _lista(json['aspectos'])) ?Aspecto.fromJson(a)],
      figuras: [for (final f in _lista(json['figuras'])) ?Figura.fromJson(f)],
      reparto: Reparto.fromJson(json['reparto']),
      luna: LunaFase.fromJson(json['luna']),
      natal: Natal.fromJson(json['natal']),
      orbes: OrbeFila.listaDe(json['orbes']),
      clasesOrbe: _lista(json['clases_orbe']).whereType<String>().toList(),
    );
  }
}

/// Un firmamento con su carta: lo que devuelven el detalle, el alta (201) y
/// el cambio de zona.
class FirmamentoDetalle {
  const FirmamentoDetalle({required this.firmamento, this.carta, this.notas = const [], this.notaIaCosto});

  final Firmamento firmamento;

  /// Para la cabecera (fecha, hora y lugar): no se lee nada más de ella.
  final Carta? carta;

  /// La más nueva primero, como las da el servidor.
  final List<NotaFirmamento> notas;

  /// Polvo estelar que cuesta la nota IA; null si el servidor no lo dice.
  final int? notaIaCosto;

  static FirmamentoDetalle? fromJson(Object? data) {
    if (data is! Map) return null;
    final f = Firmamento.fromJson(data['firmamento']);
    if (f == null) return null;
    final notas = data['notas'];
    return FirmamentoDetalle(
      firmamento: f,
      carta: Carta.fromJson(data['carta_astral']),
      notas: notas is List ? notas.map(NotaFirmamento.fromJson).whereType<NotaFirmamento>().toList() : const [],
      notaIaCosto: _i(data['nota_ia_costo']),
    );
  }
}

/// Una nota del firmamento: propia o la lectura de la IA.
class NotaFirmamento {
  const NotaFirmamento({required this.id, required this.contenido, this.esIa = false, this.creada});

  final int id;
  final String contenido;
  final bool esIa;
  final DateTime? creada;

  static NotaFirmamento? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _i(json['id']);
    if (id == null) return null;
    final creada = json['created_at'];
    return NotaFirmamento(
      id: id,
      contenido: _s(json['contenido']),
      esIa: json['es_ia'] == true,
      creada: creada is String ? DateTime.tryParse(creada)?.toLocal() : null,
    );
  }
}

class ZonaFirmamento {
  const ZonaFirmamento({
    this.timezone = '',
    this.desfase = 0,
    this.rotulo = '',
    this.horarioVerano = false,
    this.revisar = false,
    this.sugerida,
  });

  final String timezone;

  /// En segundos.
  final int desfase;
  final String rotulo;
  final bool horarioVerano;
  final bool revisar;
  final ({String timezone, int desfase, String rotulo})? sugerida;

  factory ZonaFirmamento.fromJson(Object? json) {
    if (json is! Map) return const ZonaFirmamento();
    final s = json['sugerida'];
    return ZonaFirmamento(
      timezone: _s(json['timezone']),
      desfase: _i(json['desfase']) ?? 0,
      rotulo: _s(json['rotulo']),
      horarioVerano: json['horario_verano'] == true,
      revisar: json['revisar'] == true,
      sugerida: s is Map && s['timezone'] is String
          ? (
              timezone: s['timezone'] as String,
              desfase: _i(s['desfase']) ?? 0,
              rotulo: _s(s['rotulo']),
            )
          : null,
    );
  }
}

class Eje {
  const Eje(this.longitud, this.signo, this.gradoEnSigno);

  final double longitud;
  final int signo;
  final double gradoEnSigno;

  static Eje? fromJson(Object? json) {
    if (json is! Map) return null;
    final lon = _d(json['longitud']);
    if (lon == null) return null;
    return Eje(lon, _i(json['signo']) ?? (lon ~/ 30), _d(json['grado_en_signo']) ?? lon % 30);
  }
}

class Cuerpo {
  const Cuerpo({
    required this.clave,
    required this.nombre,
    required this.simbolo,
    required this.color,
    required this.longitud,
    required this.signo,
    required this.gradoEnSigno,
    required this.casa,
    this.retrogrado = false,
    this.estacionario = false,
    this.fueraDeLimites = false,
    this.dignidad,
    this.dignidadModerna = false,
    this.esPunto = false,
  });

  final String clave;
  final String nombre;
  final String simbolo;
  final Color color;
  final double longitud;
  final int signo;
  final double gradoEnSigno;
  final int casa;
  final bool retrogrado;
  final bool estacionario;
  final bool fueraDeLimites;

  /// `domicile`, `exaltation`, `detriment`, `fall` o `null`.
  final String? dignidad;

  /// La regencia moderna (Urano, Neptuno, Plutón): va entre paréntesis.
  final bool dignidadModerna;

  /// Quirón, nodos y Lilith.
  final bool esPunto;

  static Cuerpo? fromJson(Object? json) {
    if (json is! Map) return null;
    final clave = json['clave'];
    final lon = _d(json['longitud']);
    if (clave is! String || lon == null) return null;
    final dig = json['dignidad'];
    return Cuerpo(
      clave: clave,
      nombre: _s(json['nombre'], clave),
      simbolo: _s(json['simbolo'], '•'),
      color: colorHex(json['color']),
      longitud: lon,
      signo: _i(json['signo']) ?? (lon ~/ 30),
      gradoEnSigno: _d(json['grado_en_signo']) ?? lon % 30,
      casa: _i(json['casa']) ?? 0,
      retrogrado: json['retrogrado'] == true,
      estacionario: json['estacionario'] == true,
      fueraDeLimites: json['fuera_de_limites'] == true,
      dignidad: dig is Map && dig['type'] is String ? dig['type'] as String : null,
      dignidadModerna: dig is Map && dig['modern'] == true,
      esPunto: json['es_punto'] == true,
    );
  }
}

class Aspecto {
  const Aspecto({
    required this.a,
    required this.b,
    required this.tipo,
    required this.nombre,
    required this.simbolo,
    required this.color,
    required this.orbe,
    required this.orbeDm,
    required this.exactitud,
    required this.aplicativo,
    required this.grupo,
  });

  final String a;
  final String b;
  final String tipo;
  final String nombre;
  final String simbolo;
  final Color color;
  final double orbe;
  final String orbeDm;

  /// 0 a 1: más grueso y opaco cuanto más exacto.
  final double exactitud;
  final bool aplicativo;

  /// `mayores`, `ejes` o `menores`.
  final String grupo;

  bool get menor => grupo == 'menores';

  /// Une a [x] e [y], en cualquier orden.
  bool une(String x, String y) => (a == x && b == y) || (a == y && b == x);

  bool toca(String clave) => a == clave || b == clave;

  static Aspecto? fromJson(Object? json) {
    if (json is! Map) return null;
    final a = json['a'], b = json['b'];
    if (a is! String || b is! String) return null;
    final orbe = _d(json['orbe']) ?? 0;
    return Aspecto(
      a: a,
      b: b,
      tipo: _s(json['tipo']),
      nombre: _s(json['nombre']),
      simbolo: _s(json['simbolo']),
      color: colorHex(json['color']),
      orbe: orbe,
      orbeDm: _s(json['orbe_dm'], gradoMinutos(orbe)),
      exactitud: (_d(json['exactitud']) ?? 0.5).clamp(0, 1).toDouble(),
      aplicativo: json['aplicativo'] == true,
      grupo: _s(json['grupo'], 'mayores'),
    );
  }
}

class Figura {
  const Figura({
    required this.tipo,
    required this.etiqueta,
    this.detalle,
    required this.cuerpos,
    required this.asociados,
    required this.color,
  });

  final String tipo;
  final String etiqueta;
  final String? detalle;
  final List<String> cuerpos;
  final List<String> asociados;
  final Color color;

  static Figura? fromJson(Object? json) {
    if (json is! Map) return null;
    final detalle = json['detalle'];
    return Figura(
      tipo: _s(json['tipo']),
      etiqueta: _s(json['etiqueta']),
      detalle: detalle is String && detalle.isNotEmpty ? detalle : null,
      cuerpos: _lista(json['cuerpos']).whereType<String>().toList(),
      asociados: _lista(json['asociados']).whereType<String>().toList(),
      color: colorHex(json['color']),
    );
  }
}

class RepartoItem {
  const RepartoItem(this.nombre, this.weight, this.count, this.color, this.frac);

  final String nombre;
  final double weight;
  final int count;
  final Color color;
  final double frac;
}

class Reparto {
  const Reparto(this.elementos, this.modalidades, this.total);

  final List<RepartoItem> elementos;
  final List<RepartoItem> modalidades;
  final double total;

  static Reparto? fromJson(Object? json) {
    if (json is! Map) return null;
    List<RepartoItem> items(Object? m) => m is Map
        ? [
            for (final e in m.entries)
              if (e.value is Map)
                RepartoItem(
                  '${e.key}',
                  _d(e.value['weight']) ?? 0,
                  _i(e.value['count']) ?? 0,
                  colorHex(e.value['color'], respaldo: kElementos['${e.key}'] ?? kTextoTenue),
                  (_d(e.value['frac']) ?? 0).clamp(0, 1).toDouble(),
                ),
          ]
        : const [];
    return Reparto(items(json['elements']), items(json['modalities']), _d(json['total']) ?? 0);
  }
}

class LunaFase {
  const LunaFase(this.rudhyar, this.elongacion, this.iluminacion);

  final String rudhyar;
  final double? elongacion;
  final double? iluminacion;

  static LunaFase? fromJson(Object? json) {
    if (json is! Map) return null;
    return LunaFase(_s(json['rudhyar']), _d(json['elongacion']), _d(json['iluminacion']));
  }
}

class Prenatal {
  const Prenatal({
    required this.type,
    this.label,
    required this.timestamp,
    required this.longitud,
    required this.signo,
    required this.casa,
  });

  /// `new`/`full` en la lunación; tipo de eclipse en los eclipses.
  final String type;
  final String? label;

  /// Segundos UTC.
  final int timestamp;
  final double longitud;
  final int signo;
  final int casa;

  static Prenatal? fromJson(Object? json) {
    if (json is! Map) return null;
    final ts = _i(json['timestamp']);
    final lon = _d(json['longitude']);
    if (ts == null || lon == null) return null;
    return Prenatal(
      type: _s(json['type']),
      label: json['label'] is String ? json['label'] as String : null,
      timestamp: ts,
      longitud: lon,
      signo: _i(json['sign']) ?? (lon ~/ 30),
      casa: _i(json['house']) ?? 0,
    );
  }
}

class Natal {
  const Natal({
    this.bigThree,
    this.chartRuler,
    this.secta,
    this.angulares = const [],
    this.cerrados = const [],
    this.dominante,
    this.masFuerte,
    this.regentesCasas = const [],
    this.hemisferios,
    this.lunacion,
    this.eclipseSolar,
    this.eclipseLunar,
  });

  /// Índices de signo del Sol, la Luna y el Ascendente.
  final ({int? sun, int? moon, int? asc})? bigThree;
  final ({String body, String? modern, int sign, int house, String? dignity})? chartRuler;

  /// `diurnal` o `nocturnal`, con su luminar.
  final ({String type, String luminary})? secta;
  final List<({String body, String angle, double distance})> angulares;
  final List<AspectoCerrado> cerrados;
  final ({String element, String modality})? dominante;
  final ({String body, List<String> reasons, int aspects})? masFuerte;

  /// 12 entradas, casa I primero (`null` si falta alguna).
  final List<({String ruler, String? modern, int house, int sign})?> regentesCasas;
  final ({int above, int below, int east, int west, int total})? hemisferios;
  final Prenatal? lunacion;
  final Prenatal? eclipseSolar;
  final Prenatal? eclipseLunar;

  factory Natal.fromJson(Object? json) {
    if (json is! Map) return const Natal();
    final bt = json['big_three'];
    final cr = json['chart_ruler'];
    final sect = json['sect'];
    final dom = json['dominant'];
    final st = json['strongest'];
    final hem = json['hemispheres'];
    final pre = json['prenatal'];

    // Llega como lista (casa I primero) o como mapa {1..12}.
    final rawHr = json['house_rulers'];
    final hrLista = rawHr is List
        ? rawHr
        : rawHr is Map
            ? [for (var i = 1; i <= 12; i++) rawHr['$i'] ?? rawHr[i]]
            : const [];
    final regentes = [
      for (final r in hrLista)
        r is Map && r['ruler'] is String
            ? (
                ruler: r['ruler'] as String,
                modern: r['modern'] is String ? r['modern'] as String : null,
                house: _i(r['ruler_house']) ?? 0,
                sign: _i(r['ruler_sign']) ?? 0,
              )
            : null,
    ];

    return Natal(
      bigThree: bt is Map ? (sun: _i(bt['sun']), moon: _i(bt['moon']), asc: _i(bt['asc'])) : null,
      chartRuler: cr is Map && cr['body'] is String
          ? (
              body: cr['body'] as String,
              modern: cr['modern'] is String ? cr['modern'] as String : null,
              sign: _i(cr['sign']) ?? 0,
              house: _i(cr['house']) ?? 0,
              dignity: cr['dignity'] is String ? cr['dignity'] as String : null,
            )
          : null,
      secta: sect is Map && sect['type'] is String
          ? (type: sect['type'] as String, luminary: _s(sect['luminary']))
          : null,
      angulares: [
        for (final a in _lista(json['angular']))
          if (a is Map && a['body'] is String)
            (body: a['body'] as String, angle: _s(a['angle']), distance: _d(a['distance']) ?? 0),
      ],
      cerrados: [for (final a in _lista(json['tight_aspects'])) ?AspectoCerrado.fromJson(a)],
      dominante: dom is Map
          ? (element: _s(dom['element']), modality: _s(dom['modality']))
          : null,
      masFuerte: st is Map && st['body'] is String
          ? (
              body: st['body'] as String,
              reasons: _lista(st['reasons']).whereType<String>().toList(),
              aspects: _i(st['aspects']) ?? 0,
            )
          : null,
      regentesCasas: regentes.length == 12 ? regentes : const [],
      hemisferios: hem is Map
          ? (
              above: _i(hem['above']) ?? 0,
              below: _i(hem['below']) ?? 0,
              east: _i(hem['east']) ?? 0,
              west: _i(hem['west']) ?? 0,
              total: _i(hem['total']) ?? 0,
            )
          : null,
      lunacion: pre is Map ? Prenatal.fromJson(pre['lunation']) : null,
      eclipseSolar: pre is Map ? Prenatal.fromJson(pre['eclipse_solar']) : null,
      eclipseLunar: pre is Map ? Prenatal.fromJson(pre['eclipse_lunar']) : null,
    );
  }
}

/// Uno de los 3 aspectos más cerrados (`natal.tight_aspects`).
class AspectoCerrado {
  const AspectoCerrado({
    required this.a,
    required this.b,
    required this.nombre,
    required this.simbolo,
    required this.color,
    required this.orbeDm,
    required this.aplicativo,
  });

  final String a;
  final String b;
  final String nombre;
  final String simbolo;
  final Color color;
  final String orbeDm;
  final bool aplicativo;

  static AspectoCerrado? fromJson(Object? json) {
    if (json is! Map) return null;
    final a = json['a'], b = json['b'];
    if (a is! String || b is! String) return null;
    return AspectoCerrado(
      a: a,
      b: b,
      nombre: _s(json['name']),
      simbolo: _s(json['symbol']),
      color: colorHex(json['color']),
      orbeDm: _s(json['orb_dm']),
      aplicativo: json['applying'] == true,
    );
  }
}

/// Una fila de la tabla de orbes: un aspecto y su orbe por clase de cuerpo.
class OrbeFila {
  const OrbeFila(this.nombre, this.simbolo, this.orbes);

  final String nombre;
  final String simbolo;
  final List<double> orbes;

  // Llega como mapa por tipo o como lista.
  static List<OrbeFila> listaDe(Object? json) {
    final filas = json is Map ? json.values : (json is List ? json : const []);
    return [
      for (final f in filas)
        if (f is Map)
          OrbeFila(
            _s(f['nombre']),
            _s(f['simbolo']),
            _lista(f['orbes']).map(_d).whereType<double>().toList(),
          ),
    ];
  }
}

List<dynamic> _lista(Object? v) => v is List ? v : const [];

String _s(Object? v, [String respaldo = '']) => v is String ? v : respaldo;

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

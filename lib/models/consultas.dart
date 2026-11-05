import 'package:flutter/foundation.dart';

import '../theme/consultas_theme.dart';

/// Un tema del catálogo de preguntas (`{icono, titulo, preguntas}`).
@immutable
class GrupoPreguntas {
  const GrupoPreguntas({required this.icono, required this.titulo, required this.preguntas});

  final String icono;
  final String titulo;
  final List<String> preguntas;

  static GrupoPreguntas? fromJson(Object? json) {
    if (json is! Map) return null;
    final preguntas = _strings(json['preguntas']);
    if (preguntas.isEmpty) return null;
    return GrupoPreguntas(
      icono: _str(json['icono']),
      titulo: _str(json['titulo']),
      preguntas: preguntas,
    );
  }
}

/// Una IA del registro del servidor. Las no configuradas se muestran
/// deshabilitadas, no se ocultan.
@immutable
class ProveedorIa {
  const ProveedorIa({required this.clave, required this.etiqueta, this.disponible = true});

  final String clave;
  final String etiqueta;
  final bool disponible;

  static ProveedorIa? fromJson(Object? json) {
    if (json is! Map || json['clave'] is! String) return null;
    return ProveedorIa(
      clave: json['clave'] as String,
      etiqueta: _str(json['etiqueta'], json['clave'] as String),
      disponible: json['disponible'] != false,
    );
  }
}

/// Un nivel de profundidad: `basico`, `intermedio` o `premium`.
@immutable
class NivelConsulta {
  const NivelConsulta({
    required this.clave,
    required this.nombre,
    required this.costo,
    required this.tokens,
    this.descripcion = '',
  });

  final String clave;
  final String nombre;
  final int costo;
  final int tokens;
  final String descripcion;

  static NivelConsulta? fromJson(Object? json) {
    if (json is! Map || json['clave'] is! String) return null;
    return NivelConsulta(
      clave: json['clave'] as String,
      nombre: _str(json['nombre'], json['clave'] as String),
      costo: _int(json['costo']) ?? 0,
      tokens: _int(json['tokens']) ?? 0,
      descripcion: _str(json['descripcion']),
    );
  }
}

/// `GET /api/consultas/catalogo`.
@immutable
class CatalogoConsultas {
  const CatalogoConsultas({
    required this.preguntasOraculo,
    required this.preguntasDemeter,
    required this.cultivos,
    required this.proveedoresConsulta,
    required this.proveedoresCompatibilidad,
    required this.porDefectoConsulta,
    required this.porDefectoCompatibilidad,
    required this.niveles,
    this.nivelPorDefecto = 'basico',
    this.costoFirmamento = 50,
    this.tokensFirmamento = 200,
  });

  final List<GrupoPreguntas> preguntasOraculo;
  final List<GrupoPreguntas> preguntasDemeter;
  final List<String> cultivos;
  final List<ProveedorIa> proveedoresConsulta;
  final List<ProveedorIa> proveedoresCompatibilidad;
  final String porDefectoConsulta;
  final String porDefectoCompatibilidad;
  final Map<ModuloConsulta, List<NivelConsulta>> niveles;
  final String nivelPorDefecto;
  final int costoFirmamento;
  final int tokensFirmamento;

  List<GrupoPreguntas> preguntas(ModuloConsulta m) =>
      m == ModuloConsulta.demeter ? preguntasDemeter : preguntasOraculo;

  List<ProveedorIa> proveedores(ModuloConsulta m) =>
      m == ModuloConsulta.persefone ? proveedoresCompatibilidad : proveedoresConsulta;

  String porDefecto(ModuloConsulta m) =>
      m == ModuloConsulta.persefone ? porDefectoCompatibilidad : porDefectoConsulta;

  List<NivelConsulta> nivelesDe(ModuloConsulta m) => niveles[m] ?? const [];

  NivelConsulta? nivel(ModuloConsulta m, String clave) {
    for (final n in nivelesDe(m)) {
      if (n.clave == clave) return n;
    }
    return nivelesDe(m).firstOrNull;
  }

  /// El tema de una pregunta del catálogo, para la vista previa.
  String? temaDe(ModuloConsulta m, String pregunta) {
    for (final g in preguntas(m)) {
      if (g.preguntas.contains(pregunta)) return g.titulo;
    }
    return null;
  }

  static CatalogoConsultas fromJson(Map<String, dynamic> json) {
    final preguntas = json['preguntas'] is Map ? json['preguntas'] as Map : const {};
    final proveedores = json['proveedores'] is Map ? json['proveedores'] as Map : const {};
    final defecto = json['por_defecto'] is Map ? json['por_defecto'] as Map : const {};
    final niveles = json['niveles'] is Map ? json['niveles'] as Map : const {};

    List<T> lista<T>(Object? v, T? Function(Object?) f) =>
        v is List ? v.map(f).whereType<T>().toList() : <T>[];

    return CatalogoConsultas(
      preguntasOraculo: lista(preguntas['oraculo'], GrupoPreguntas.fromJson),
      preguntasDemeter: lista(preguntas['demeter'], GrupoPreguntas.fromJson),
      cultivos: _strings(json['cultivos']),
      proveedoresConsulta: lista(proveedores['consulta'], ProveedorIa.fromJson),
      proveedoresCompatibilidad: lista(proveedores['compatibilidad'], ProveedorIa.fromJson),
      porDefectoConsulta: _str(defecto['consulta'], 'gemini'),
      porDefectoCompatibilidad: _str(defecto['compatibilidad'], 'gemini'),
      niveles: {
        for (final m in ModuloConsulta.consola) m: lista(niveles[m.clave], NivelConsulta.fromJson),
      },
      nivelPorDefecto: _str(json['nivel_por_defecto'], 'basico'),
      costoFirmamento: _int(json['costo_firmamento']) ?? 50,
      tokensFirmamento: _int(json['tokens_firmamento']) ?? 200,
    );
  }
}

/// Una casilla de las franjas de clima (Demeter) o de cielo (Oráculo).
@immutable
class CasillaFranja {
  const CasillaFranja({required this.rotulo, required this.valor, this.nota, this.color});

  final String rotulo;
  final String valor;
  final String? nota;

  /// `#rrggbb` del signo, o `null`.
  final String? color;

  static CasillaFranja? fromJson(Object? json) {
    if (json is! Map) return null;
    return CasillaFranja(
      rotulo: _str(json['rotulo']),
      valor: _str(json['valor'], '—'),
      nota: json['nota'] is String ? json['nota'] as String : null,
      color: json['color'] is String ? json['color'] as String : null,
    );
  }
}

/// `GET /api/consultas/contexto`: sin coordenadas.
@immutable
class ContextoMomento {
  const ContextoMomento({
    required this.lugar,
    required this.fecha,
    required this.hora,
    this.franjaDemeter = const [],
    this.franjaOraculo = const [],
    this.contextoDemeter = const {},
    this.contextoOraculo = const {},
  });

  final String lugar;
  final String fecha;
  final String hora;
  final List<CasillaFranja> franjaDemeter;
  final List<CasillaFranja> franjaOraculo;
  final Map<String, dynamic> contextoDemeter;
  final Map<String, dynamic> contextoOraculo;

  static ContextoMomento fromJson(Map<String, dynamic> json) {
    List<CasillaFranja> franja(Object? v) =>
        v is List ? v.map(CasillaFranja.fromJson).whereType<CasillaFranja>().toList() : const [];
    Map<String, dynamic> mapa(Object? v) => v is Map ? Map<String, dynamic>.from(v) : const {};

    return ContextoMomento(
      lugar: _str(json['lugar']),
      fecha: _str(json['fecha']),
      hora: _str(json['hora']),
      franjaDemeter: franja(json['franja_demeter']),
      franjaOraculo: franja(json['franja_oraculo']),
      contextoDemeter: mapa(json['contexto_demeter']),
      contextoOraculo: mapa(json['contexto_oraculo']),
    );
  }
}

/// Lo que devolvió una consulta (200 con `success: true`).
@immutable
class RespuestaConsulta {
  const RespuestaConsulta({
    required this.texto,
    this.desdeCache = false,
    this.fallback = false,
    this.proveedorEtiqueta,
    this.nuevoBalance,
  });

  final String texto;
  final bool desdeCache;
  final bool fallback;
  final String? proveedorEtiqueta;
  final int? nuevoBalance;

  static RespuestaConsulta fromJson(Map<String, dynamic> json) => RespuestaConsulta(
        texto: _str(json['response'] ?? json['texto']),
        desdeCache: json['from_cache'] == true,
        fallback: json['fallback'] == true,
        proveedorEtiqueta: json['proveedor_etiqueta'] is String ? json['proveedor_etiqueta'] as String : null,
        nuevoBalance: _int(json['nuevo_balance']),
      );
}

@immutable
class NotaConsulta {
  const NotaConsulta({required this.id, required this.contenido, this.creada});

  final int id;
  final String contenido;
  final DateTime? creada;

  static NotaConsulta? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _int(json['id']);
    if (id == null) return null;
    return NotaConsulta(
      id: id,
      contenido: _str(json['contenido']),
      creada: _fecha(json['created_at']),
    );
  }
}

/// Una consulta del historial (el tipo `Consulta` del contrato).
@immutable
class Consulta {
  const Consulta({
    required this.id,
    required this.modulo,
    required this.pregunta,
    required this.respuesta,
    this.fuente,
    this.modeloIa,
    this.desdeCache = false,
    this.tiempoMs,
    this.caracteres,
    this.cartaId,
    this.carta,
    this.contexto = const {},
    this.notas = const [],
    this.creada,
  });

  final int id;
  final ModuloConsulta modulo;
  final String pregunta;
  final String respuesta;
  final String? fuente;
  final String? modeloIa;
  final bool desdeCache;
  final int? tiempoMs;
  final int? caracteres;
  final int? cartaId;

  /// La copia de la carta guardada con la consulta: `{titulo, sun_degree…}`.
  final Map<String, dynamic>? carta;
  final Map<String, dynamic> contexto;
  final List<NotaConsulta> notas;
  final DateTime? creada;

  bool get usoFirmamento => cartaId != null || carta != null;

  /// Los planetas visibles guardados en el contexto, para los chips.
  List<String> get planetas => _strings(contexto['planetas_visibles']);

  Consulta conNotas(List<NotaConsulta> notas) => Consulta(
        id: id,
        modulo: modulo,
        pregunta: pregunta,
        respuesta: respuesta,
        fuente: fuente,
        modeloIa: modeloIa,
        desdeCache: desdeCache,
        tiempoMs: tiempoMs,
        caracteres: caracteres,
        cartaId: cartaId,
        carta: carta,
        contexto: contexto,
        notas: notas,
        creada: creada,
      );

  static Consulta? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _int(json['id']);
    if (id == null) return null;
    final respuesta = _str(json['respuesta']);
    return Consulta(
      id: id,
      modulo: ModuloConsulta.desde(json['modulo']),
      pregunta: _str(json['pregunta']),
      respuesta: respuesta,
      fuente: json['fuente'] is String ? json['fuente'] as String : null,
      modeloIa: json['modelo_ia'] is String ? json['modelo_ia'] as String : null,
      desdeCache: json['desde_cache'] == true,
      tiempoMs: _int(json['tiempo_respuesta_ms']),
      caracteres: _int(json['caracteres_respuesta']) ?? respuesta.length,
      cartaId: _int(json['carta_astral_id']),
      carta: json['carta_astral'] is Map ? Map<String, dynamic>.from(json['carta_astral'] as Map) : null,
      contexto: json['contexto_astronomico'] is Map
          ? Map<String, dynamic>.from(json['contexto_astronomico'] as Map)
          : const {},
      notas: json['notas'] is List
          ? (json['notas'] as List).map(NotaConsulta.fromJson).whereType<NotaConsulta>().toList()
          : const [],
      creada: _fecha(json['created_at']),
    );
  }
}

/// Una página del historial (`?page=`).
@immutable
class PaginaHistorial {
  const PaginaHistorial({required this.consultas, required this.pagina, required this.ultima, required this.total});

  final List<Consulta> consultas;
  final int pagina;
  final int ultima;
  final int total;

  bool get hayMas => pagina < ultima;
}

// ── Reglas del resumen (refrescarResumen* de la web) ─────────────────────────

/// El firmamento solo suma en el Oráculo.
int costoConsulta(NivelConsulta nivel, {bool conFirmamento = false, int costoFirmamento = 50}) =>
    nivel.costo + (conFirmamento ? costoFirmamento : 0);

/// `tokens del nivel + ⌈largo/4⌉ + 200 si hay firmamento`, como la web.
int tokensEstimados(
  NivelConsulta nivel,
  String pregunta, {
  bool conFirmamento = false,
  int tokensFirmamento = 200,
}) =>
    nivel.tokens + (pregunta.length / 4).ceil() + (conFirmamento ? tokensFirmamento : 0);

bool puedeConsultarDemeter(String? pregunta) => (pregunta ?? '').isNotEmpty;

bool puedeConsultarOraculo(String? pregunta, {required bool conFirmamento, int? cartaId}) =>
    (pregunta ?? '').isNotEmpty && (!conFirmamento || cartaId != null);

bool puedeConsultarPersefone(int? a, int? b) => a != null && b != null && a != b;

// ── Lectura tolerante del JSON ───────────────────────────────────────────────

String _str(Object? v, [String porDefecto = '']) => v is String ? v : (v == null ? porDefecto : '$v');

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

List<String> _strings(Object? v) => v is List ? v.whereType<String>().toList() : const [];

DateTime? _fecha(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

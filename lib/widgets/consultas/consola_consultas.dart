import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models/carta.dart';
import '../../models/consultas.dart';
import '../../services/anuncio_consulta.dart';
import '../../services/consultas_service.dart';
import '../../textos/consultas_textos.dart';
import '../../theme/consultas_theme.dart';
import 'cns_basicos.dart';
import 'franja_datos.dart';
import 'modulo_tabs.dart';
import 'nivel_card.dart';
import 'paso_numerado.dart';
import 'respuesta_card.dart';
import 'resumen_consulta.dart';
import 'selector_pregunta.dart';
import 'vista_previa.dart';

/// La consola de la web (`#cnsConsole`): pestañas Demeter · Oráculo ·
/// Perséfone, los pasos de cada panel, el resumen y la respuesta.
class ConsolaConsultas extends StatefulWidget {
  const ConsolaConsultas({
    super.key,
    required this.catalogo,
    required this.contexto,
    required this.cartas,
    required this.service,
    required this.anuncio,
    required this.onCrearFirmamento,
    this.onConsultaHecha,
    this.inicial = ModuloConsulta.demeter,
  });

  final CatalogoConsultas catalogo;

  /// `null` mientras carga o si falló: la consola funciona igual, sin franjas.
  final ContextoMomento? contexto;
  final List<Carta> cartas;
  final ConsultasService service;

  /// Lo carga y lo libera la pantalla; aquí solo se muestra antes de consultar.
  final AnuncioConsulta anuncio;
  final VoidCallback onCrearFirmamento;
  final VoidCallback? onConsultaHecha;
  final ModuloConsulta inicial;

  @override
  State<ConsolaConsultas> createState() => _ConsolaConsultasState();
}

class _ConsolaConsultasState extends State<ConsolaConsultas> {
  late ModuloConsulta _modulo = widget.inicial;

  late final Map<ModuloConsulta, String> _nivel = {
    for (final m in ModuloConsulta.consola) m: widget.catalogo.nivelPorDefecto,
  };
  late final Map<ModuloConsulta, String?> _proveedor = {
    for (final m in ModuloConsulta.consola) m: _proveedorInicial(m),
  };
  final Map<ModuloConsulta, String?> _pregunta = {};
  final Map<ModuloConsulta, RespuestaConsulta?> _respuesta = {};
  final Set<ModuloConsulta> _cargando = {};
  final Map<ModuloConsulta, GlobalKey> _anclaRespuesta = {
    for (final m in ModuloConsulta.consola) m: GlobalKey(),
  };

  String? _cultivo;
  bool _conFirmamento = false;
  int? _cartaId;
  int? _a;
  int? _b;
  double _giros = 0;

  CatalogoConsultas get _cat => widget.catalogo;

  /// El por defecto del servidor, o el primero disponible si ese no lo está.
  String? _proveedorInicial(ModuloConsulta m) {
    final lista = widget.catalogo.proveedores(m);
    final defecto = widget.catalogo.porDefecto(m);
    final ok = lista.where((p) => p.clave == defecto && p.disponible).firstOrNull ??
        lista.where((p) => p.disponible).firstOrNull;
    return ok?.clave ?? defecto;
  }

  @override
  void didUpdateWidget(ConsolaConsultas old) {
    super.didUpdateWidget(old);
    // Un firmamento borrado deja de estar elegido.
    final ids = widget.cartas.map((c) => c.id).toSet();
    if (_cartaId != null && !ids.contains(_cartaId)) _cartaId = null;
    if (_a != null && !ids.contains(_a)) _a = null;
    if (_b != null && !ids.contains(_b)) _b = null;
  }

  String _titulo(int? id) {
    final carta = widget.cartas.where((c) => c.id == id).firstOrNull;
    if (carta == null) return TxConsultas.sinElegir;
    return carta.titulo.trim().isEmpty ? TxConsultas.firmamentoSinTitulo : carta.titulo;
  }

  NivelConsulta get _nivelActual =>
      _cat.nivel(_modulo, _nivel[_modulo]!) ?? const NivelConsulta(clave: 'basico', nombre: '—', costo: 0, tokens: 0);

  bool get _usaFirmamento => _conFirmamento && _cartaId != null;

  bool get _valido => switch (_modulo) {
        ModuloConsulta.demeter => puedeConsultarDemeter(_pregunta[_modulo]),
        ModuloConsulta.persefone => puedeConsultarPersefone(_a, _b),
        _ => puedeConsultarOraculo(_pregunta[_modulo], conFirmamento: _conFirmamento, cartaId: _cartaId),
      };

  // ── Consultar ─────────────────────────────────────────────────────────────

  void _consultar() {
    if (!_valido || _cargando.contains(_modulo)) return;
    widget.anuncio.mostrarYLuego(() => _enviar(_modulo));
  }

  Future<void> _enviar(ModuloConsulta m) async {
    setState(() => _cargando.add(m));
    try {
      final nivel = _nivel[m]!;
      final r = switch (m) {
        ModuloConsulta.persefone => await widget.service.compatibilidad(
            cartaA: _a!,
            cartaB: _b!,
            nivel: nivel,
            proveedor: _proveedor[m],
          ),
        ModuloConsulta.demeter => await widget.service.consultar(
            modulo: m,
            pregunta: _pregunta[m]!,
            nivel: nivel,
            proveedor: _proveedor[m],
            contexto: {...?widget.contexto?.contextoDemeter, 'cultivo': ?_cultivo},
          ),
        _ => await widget.service.consultar(
            modulo: m,
            pregunta: _pregunta[m]!,
            nivel: nivel,
            proveedor: _proveedor[m],
            contexto: widget.contexto?.contextoOraculo ?? const {},
            cartaId: _conFirmamento ? _cartaId : null,
          ),
      };
      if (!mounted) return;
      setState(() => _respuesta[m] = r);
      final ia = r.proveedorEtiqueta == null ? '' : ' · ${r.proveedorEtiqueta}';
      avisoConsola(
        context,
        r.desdeCache
            ? '${TxConsultas.desdeCacheAviso}$ia'
            : r.fallback
                ? TxConsultas.modoLocal
                : '${TxConsultas.completada}$ia',
      );
      _irARespuesta(m);
      widget.onConsultaHecha?.call();
    } on ConsultaFallida catch (e) {
      if (!mounted) return;
      avisoConsola(
        context,
        e.sinSaldo ? TxConsultas.sinSaldo : e.mensaje,
        error: true,
        accion: e.sinSaldo
            ? SnackBarAction(
                label: TxConsultas.irTienda,
                textColor: CnsColores.ambar,
                onPressed: () => Navigator.of(context).pushNamed('/store'),
              )
            : null,
      );
    } catch (_) {
      if (!mounted) return;
      avisoConsola(context, _errorDe(m), error: true);
    } finally {
      if (mounted) setState(() => _cargando.remove(m));
    }
  }

  String _errorDe(ModuloConsulta m) => switch (m) {
        ModuloConsulta.demeter => TxConsultas.errorDemeter,
        ModuloConsulta.persefone => TxConsultas.errorPersefone,
        _ => TxConsultas.errorOraculo,
      };

  void _irARespuesta(ModuloConsulta m) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _anclaRespuesta[m]!.currentContext;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: MediaQuery.disableAnimationsOf(ctx) ? Duration.zero : const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  void _intercambiar() => setState(() {
        final a = _a;
        _a = _b;
        _b = a;
        _giros += .5;
      });

  // ── Construcción ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final telefono = MediaQuery.sizeOf(context).width < CnsEspacios.anchoTelefono;
    final sinAnimar = MediaQuery.disableAnimationsOf(context);
    final radio = telefono ? CnsRadios.consolaTelefono : CnsRadios.consola;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(color: CnsColores.slate(.12)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [CnsColores.consolaA, CnsColores.consolaB],
        ),
        boxShadow: const [BoxShadow(color: CnsColores.sombra, blurRadius: 60, offset: Offset(0, 26))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ModuloTabs(activo: _modulo, onCambio: (m) => setState(() => _modulo = m)),
          AnimatedSwitcher(
            duration: sinAnimar ? Duration.zero : CnsDuraciones.panel,
            switchInCurve: Curves.easeOut,
            layoutBuilder: (actual, _) => actual ?? const SizedBox.shrink(),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: AnimatedBuilder(
                animation: anim,
                builder: (context, c) => Transform.translate(offset: Offset(0, 8 * (1 - anim.value)), child: c),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_modulo),
              child: Padding(
                padding: telefono
                    ? const EdgeInsets.symmetric(horizontal: 16, vertical: 20)
                    : const EdgeInsets.symmetric(horizontal: 30, vertical: 32),
                child: _panel(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel() {
    final m = _modulo;
    final estilo = m.estilo;
    final (nombre, descripcion) = switch (m) {
      ModuloConsulta.demeter => (
          TxConsultas.demeterNombre,
          TxConsultas.demeterDescripcion(_corto(widget.contexto?.lugar ?? '—', 30)),
        ),
      ModuloConsulta.persefone => (TxConsultas.persefoneNombre, TxConsultas.persefoneDescripcion),
      _ => (TxConsultas.oraculoNombre, TxConsultas.oraculoDescripcion),
    };
    final franja = switch (m) {
      ModuloConsulta.demeter => widget.contexto?.franjaDemeter ?? const <CasillaFranja>[],
      ModuloConsulta.oraculo => widget.contexto?.franjaOraculo ?? const <CasillaFranja>[],
      _ => const <CasillaFranja>[],
    };

    final pasos = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _pasos(m, estilo));
    final resumen = _resumen(m, estilo);
    final respuesta = _respuesta[m];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 18),
          margin: const EdgeInsets.only(bottom: 22),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: CnsColores.slate(.1)))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre, style: CnsTipos.serifStyle(size: 21.5)),
              const SizedBox(height: 6),
              Text(descripcion, style: TextStyle(fontSize: 13.3, height: 1.6, color: CnsColores.slate(.7))),
            ],
          ),
        ),
        if (franja.isNotEmpty) ...[
          FranjaDatos(casillas: franja, estilo: estilo),
          const SizedBox(height: 24),
        ],
        LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= 900) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: pasos),
                const SizedBox(width: 36),
                SizedBox(width: 328, child: resumen),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [pasos, const SizedBox(height: 22), resumen],
          );
        }),
        KeyedSubtree(
          key: _anclaRespuesta[m],
          child: respuesta == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 26),
                  child: RespuestaCard(
                    rotulo: switch (m) {
                      ModuloConsulta.demeter => TxConsultas.demeterRespuesta,
                      ModuloConsulta.persefone => TxConsultas.persefoneRespuesta,
                      _ => TxConsultas.oraculoRespuesta,
                    },
                    texto: respuesta.texto,
                    estilo: estilo,
                    cerrar: m == ModuloConsulta.persefone ? TxConsultas.cerrar : TxConsultas.limpiar,
                    onCerrar: () => setState(() => _respuesta.remove(m)),
                  ),
                ),
        ),
      ],
    );
  }

  List<Widget> _pasos(ModuloConsulta m, ModuloEstilo estilo) {
    final niveles = PasoNumerado(
      numero: 1,
      titulo: switch (m) {
        ModuloConsulta.demeter => TxConsultas.demeterPaso1Titulo,
        ModuloConsulta.persefone => TxConsultas.persefonePaso1Titulo,
        _ => TxConsultas.oraculoPaso1Titulo,
      },
      pista: switch (m) {
        ModuloConsulta.demeter => TxConsultas.demeterPaso1Pista,
        ModuloConsulta.persefone => TxConsultas.persefonePaso1Pista,
        _ => TxConsultas.oraculoPaso1Pista,
      },
      child: NivelesConsulta(
        niveles: _cat.nivelesDe(m),
        elegido: _nivel[m]!,
        estilo: estilo,
        onElegir: (n) => setState(() => _nivel[m] = n),
      ),
    );
    const gap = SizedBox(height: 28);

    if (m == ModuloConsulta.persefone) {
      return [
        niveles,
        gap,
        PasoNumerado(
          numero: 2,
          titulo: TxConsultas.persefonePaso2Titulo,
          pista: TxConsultas.persefonePaso2Pista,
          child: widget.cartas.length > 1 ? _par(estilo) : _notaFaltan(),
        ),
      ];
    }

    final pregunta = PasoNumerado(
      numero: 2,
      titulo: m == ModuloConsulta.demeter ? TxConsultas.demeterPaso2Titulo : TxConsultas.oraculoPaso2Titulo,
      pista: m == ModuloConsulta.demeter ? TxConsultas.demeterPaso2Pista : TxConsultas.oraculoPaso2Pista,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectorPregunta(
            grupos: _cat.preguntas(m),
            elegida: _pregunta[m],
            estilo: estilo,
            onElegir: (p) => setState(() => _pregunta[m] = p),
          ),
          const SizedBox(height: 13),
          VistaPrevia(
            pregunta: _pregunta[m],
            tema: _pregunta[m] == null ? null : _cat.temaDe(m, _pregunta[m]!),
            estilo: estilo,
          ),
        ],
      ),
    );

    final tercero = m == ModuloConsulta.demeter
        ? PasoNumerado(
            numero: 3,
            titulo: TxConsultas.demeterPaso3Titulo,
            pista: TxConsultas.demeterPaso3Pista,
            child: CnsCampo(
              texto: _cultivo == null ? TxConsultas.sinEspecificar : _mayuscula(_cultivo!),
              vacio: _cultivo == null,
              onTap: () async {
                const ninguno = '';
                final elegido = await mostrarOpciones<String>(
                  context,
                  titulo: TxConsultas.demeterPaso3Titulo,
                  estilo: estilo,
                  elegida: _cultivo ?? ninguno,
                  secciones: [
                    SeccionHoja(null, [
                      const OpcionHoja(ninguno, TxConsultas.sinEspecificar),
                      for (final c in _cat.cultivos) OpcionHoja(c, _mayuscula(c)),
                    ]),
                  ],
                );
                if (elegido != null) setState(() => _cultivo = elegido.isEmpty ? null : elegido);
              },
            ),
          )
        : PasoNumerado(
            numero: 3,
            titulo: TxConsultas.oraculoPaso3Titulo,
            pista: TxConsultas.oraculoPaso3Pista,
            child: widget.cartas.isEmpty ? _notaSinFirmamentos() : _firmamento(estilo),
          );

    return [niveles, gap, pregunta, gap, tercero];
  }

  Widget _firmamento(ModuloEstilo estilo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: CnsColores.brillo,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CnsRadios.tarjeta),
            side: BorderSide(color: CnsColores.slate(.12)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SwitchListTile(
            key: const ValueKey('usar-firmamento'),
            value: _conFirmamento,
            onChanged: (v) => setState(() => _conFirmamento = v),
            activeThumbColor: CnsColores.titulo,
            activeTrackColor: estilo.insigniaTexto,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            title: Text(TxConsultas.usarFirmamento,
                style: TextStyle(fontSize: 13.3, color: CnsColores.slate300.withValues(alpha: .85))),
            subtitle: Text(TxConsultas.usarFirmamentoDetalle, style: TextStyle(fontSize: 11, color: CnsColores.slate(.6))),
          ),
        ),
        _desplegable(
          !_conFirmamento
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _campoCarta(
                    clave: 'carta-oraculo',
                    vacio: TxConsultas.seleccionaFirmamento,
                    elegida: _cartaId,
                    estilo: estilo,
                    onElegir: (id) => setState(() => _cartaId = id),
                  ),
                ),
        ),
      ],
    );
  }

  /// AnimatedSize con duración cero falla al relayout: sin animaciones, nada.
  Widget _desplegable(Widget child) => MediaQuery.disableAnimationsOf(context)
      ? child
      : AnimatedSize(duration: CnsDuraciones.nivel, alignment: Alignment.topCenter, child: child);

  Widget _campoCarta({
    required String clave,
    required String vacio,
    required int? elegida,
    required ModuloEstilo estilo,
    required ValueChanged<int> onElegir,
  }) {
    return CnsCampo(
      key: ValueKey(clave),
      texto: elegida == null ? vacio : _titulo(elegida),
      vacio: elegida == null,
      onTap: () async {
        final id = await mostrarOpciones<int>(
          context,
          titulo: vacio,
          estilo: estilo,
          elegida: elegida,
          secciones: [
            SeccionHoja(null, [for (final c in widget.cartas) OpcionHoja(c.id, _titulo(c.id))]),
          ],
        );
        if (id != null) onElegir(id);
      },
    );
  }

  Widget _par(ModuloEstilo estilo) {
    final a = _campoCarta(
      clave: 'persona-a',
      vacio: TxConsultas.personaAOpcion,
      elegida: _a,
      estilo: estilo,
      onElegir: (id) => setState(() => _a = id),
    );
    final b = _campoCarta(
      clave: 'persona-b',
      vacio: TxConsultas.personaBOpcion,
      elegida: _b,
      estilo: estilo,
      onElegir: (id) => setState(() => _b = id),
    );
    final boton = Tooltip(
      message: TxConsultas.intercambiar,
      child: Semantics(
        label: TxConsultas.intercambiarAria,
        button: true,
        child: InkResponse(
          key: const ValueKey('intercambiar'),
          onTap: _intercambiar,
          radius: 24,
          child: AnimatedRotation(
            turns: _giros,
            duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : CnsDuraciones.giro,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CnsColores.pozoHondo,
                border: Border.all(color: estilo.nivelBorde.withValues(alpha: .4)),
              ),
              child: Icon(Icons.swap_vert_rounded, size: 18, color: estilo.insigniaTexto),
            ),
          ),
        ),
      ),
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= CnsEspacios.anchoFranjaAncha) {
        return Row(children: [
          Expanded(child: a),
          const SizedBox(width: 10),
          boton,
          const SizedBox(width: 10),
          Expanded(child: b),
        ]);
      }
      return Column(children: [a, const SizedBox(height: 10), boton, const SizedBox(height: 10), b]);
    });
  }

  Widget _notaConEnlace(String antes, String enlace, String despues) {
    return _Nota(antes: antes, enlace: enlace, despues: despues, onEnlace: widget.onCrearFirmamento);
  }

  Widget _notaSinFirmamentos() => _notaConEnlace(
        TxConsultas.sinFirmamentosAntes,
        TxConsultas.crearPrimerFirmamento,
        TxConsultas.sinFirmamentosDespues,
      );

  Widget _notaFaltan() => _notaConEnlace(TxConsultas.faltanFirmamentosAntes, TxConsultas.crearFirmamento, '.');

  Widget _resumen(ModuloConsulta m, ModuloEstilo estilo) {
    final nivel = _nivelActual;
    final pregunta = _pregunta[m] ?? '';
    final List<(String, String)> filas;
    final String linea;
    var costo = nivel.costo;

    switch (m) {
      case ModuloConsulta.persefone:
        filas = [
          (TxConsultas.nivel, nivel.nombre),
          (TxConsultas.persefoneResumenA, _a == null ? TxConsultas.sinElegir : _titulo(_a)),
          (TxConsultas.persefoneResumenB, _b == null ? TxConsultas.sinElegir : _titulo(_b)),
        ];
        linea = TxConsultas.lecturaRelacional;
      case ModuloConsulta.demeter:
        filas = [
          (TxConsultas.nivel, nivel.nombre),
          (TxConsultas.demeterResumenConsulta, pregunta.isEmpty ? TxConsultas.sinElegir : pregunta),
          (TxConsultas.demeterResumenCultivo, _cultivo == null ? TxConsultas.sinEspecificar : _mayuscula(_cultivo!)),
        ];
        linea = '~ ${tokensEstimados(nivel, pregunta)} ${TxConsultas.tokensEstimados}';
      default:
        filas = [
          (TxConsultas.nivel, nivel.nombre),
          (TxConsultas.oraculoResumenPregunta, pregunta.isEmpty ? TxConsultas.sinElegir : pregunta),
          (
            TxConsultas.oraculoResumenContexto,
            _usaFirmamento ? TxConsultas.cieloActualMas(_titulo(_cartaId)) : TxConsultas.cieloActual,
          ),
        ];
        costo = costoConsulta(nivel, conFirmamento: _conFirmamento, costoFirmamento: _cat.costoFirmamento);
        linea = '~ ${tokensEstimados(
          nivel,
          pregunta,
          conFirmamento: _conFirmamento,
          tokensFirmamento: _cat.tokensFirmamento,
        )} ${TxConsultas.tokensEstimados}';
    }

    final persefone = m == ModuloConsulta.persefone;
    return ResumenConsulta(
      estilo: estilo,
      filas: filas,
      costo: costo,
      lineaTokens: linea,
      boton: persefone ? TxConsultas.persefoneBoton : TxConsultas.consultar,
      textoCargando: persefone ? TxConsultas.conectando : TxConsultas.consultando,
      habilitado: _valido,
      cargando: _cargando.contains(m),
      onConsultar: _consultar,
      proveedores: _cat.proveedores(m),
      proveedor: _proveedor[m],
      onProveedor: (p) => setState(() => _proveedor[m] = p),
    );
  }

  static String _mayuscula(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String _corto(String s, int max) => s.length <= max ? s : '${s.substring(0, max)}...';
}

/// Nota punteada con un enlace (`.cns-note`).
class _Nota extends StatefulWidget {
  const _Nota({required this.antes, required this.enlace, required this.despues, required this.onEnlace});

  final String antes;
  final String enlace;
  final String despues;
  final VoidCallback onEnlace;

  @override
  State<_Nota> createState() => _NotaState();
}

class _NotaState extends State<_Nota> {
  late final TapGestureRecognizer _tap = TapGestureRecognizer()..onTap = widget.onEnlace;

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CnsPunteado(
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 13.3, height: 1.6, color: CnsColores.slate300.withValues(alpha: .7)),
          children: [
            TextSpan(text: widget.antes),
            TextSpan(
              text: widget.enlace,
              recognizer: _tap,
              style: const TextStyle(
                color: CnsColores.cianClaro,
                decoration: TextDecoration.underline,
                decorationColor: CnsColores.cianClaro,
              ),
            ),
            TextSpan(text: widget.despues),
          ],
        ),
      ),
    );
  }
}

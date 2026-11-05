import 'dart:async';

import 'package:flutter/material.dart';

import '../models/consultas.dart';
import '../services/api_client.dart';
import '../services/consultas_service.dart';
import '../textos/consultas_textos.dart';
import '../theme/consultas_theme.dart';
import '../widgets/consultas/cns_basicos.dart';
import '../widgets/consultas/fondo_consultas.dart';
import '../widgets/consultas/respuesta_card.dart';
import 'firmamento_detail_screen.dart';

/// El detalle de una consulta, como consultas/show de la web: sello del
/// módulo, la pregunta, la respuesta, parámetros, el cielo del momento, el
/// firmamento usado, el contexto enviado y las notas.
///
/// Al volver devuelve la consulta con sus notas al día.
class ConsultaDetalleScreen extends StatefulWidget {
  const ConsultaDetalleScreen({super.key, required this.consultaId, this.inicial, this.service});

  final int consultaId;

  /// La del historial, para pintar mientras llega el detalle.
  final Consulta? inicial;
  final ConsultasService? service;

  @override
  State<ConsultaDetalleScreen> createState() => _ConsultaDetalleScreenState();
}

class _ConsultaDetalleScreenState extends State<ConsultaDetalleScreen> {
  late final ConsultasService _service = widget.service ?? ConsultasService();
  late Consulta? _consulta = widget.inicial;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    unawaited(_cargar());
  }

  Future<void> _cargar() async {
    try {
      final c = await _service.detalle(widget.consultaId);
      if (mounted) setState(() => _consulta = c);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _volver() => Navigator.of(context).pop(_consulta);

  @override
  Widget build(BuildContext context) {
    final c = _consulta;
    return PopScope<Consulta>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _volver();
      },
      child: Scaffold(
        backgroundColor: CnsColores.fondoA,
        appBar: AppBar(
          backgroundColor: CnsColores.fondoA,
          surfaceTintColor: Colors.transparent,
          foregroundColor: CnsColores.texto,
          leading: BackButton(onPressed: _volver),
          title: Text(TxConsultas.detalleTitulo, style: CnsTipos.serifStyle(size: 18)),
        ),
        body: FondoConsultas(
          child: c == null
              ? Center(
                  child: _error
                      ? Text(TxConsultas.detalleError, style: TextStyle(color: CnsColores.slate(.8)))
                      : const CircularProgressIndicator(strokeWidth: 2, color: CnsColores.cian),
                )
              : _cuerpo(c),
        ),
      ),
    );
  }

  Widget _cuerpo(Consulta c) {
    final telefono = MediaQuery.sizeOf(context).width < CnsEspacios.anchoTelefono;
    final izquierda = [_pregunta(c), _respuesta(c)];
    final derecha = [
      _parametros(c),
      _cielo(c),
      if (c.usoFirmamento) _firmamento(c),
      _contexto(c),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(telefono ? 14 : 24, 16, telefono ? 14 : 24, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cabecera(c),
                const SizedBox(height: 16),
                LayoutBuilder(builder: (context, k) {
                  if (k.maxWidth < 900) return _pila([...izquierda, ...derecha]);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: _pila(izquierda)),
                      const SizedBox(width: 14),
                      Expanded(flex: 4, child: _pila(derecha)),
                    ],
                  );
                }),
                const SizedBox(height: 14),
                _NotasPanel(
                  consulta: c,
                  service: _service,
                  onNota: (n) => setState(() => _consulta = c.conNotas([n, ...c.notas])),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _pila(List<Widget> paneles) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, p) in paneles.indexed) ...[if (i > 0) const SizedBox(height: 14), p],
        ],
      );

  static String nombreModulo(ModuloConsulta m) => switch (m) {
        ModuloConsulta.demeter => TxConsultas.moduloNombreDemeter,
        ModuloConsulta.persefone => TxConsultas.moduloNombrePersefone,
        ModuloConsulta.notaIa => TxConsultas.moduloNombreNotaIa,
        ModuloConsulta.oraculo => TxConsultas.moduloNombreOraculo,
      };

  Widget _cabecera(Consulta c) {
    final estilo = c.modulo.estilo;
    final partes = [
      if (c.creada != null) haceTiempo(c.creada!),
      if (c.modeloIa != null) c.modeloIa!,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: estilo.sello),
                color: CnsColores.selloFondo,
              ),
              child: Text(estilo.icono, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombreModulo(c.modulo),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.15, color: CnsColores.detalleTitulo),
                  ),
                  const SizedBox(height: 3),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 12, color: CnsColores.detalleMeta),
                      children: [
                        if (c.creada != null)
                          TextSpan(
                            text: fechaHora(c.creada!),
                            style: const TextStyle(fontWeight: FontWeight.w600, color: CnsColores.detalleFecha),
                          ),
                        for (final p in partes) TextSpan(text: ' · $p'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (c.cartaId != null) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: _BotonPrimario(texto: TxConsultas.verFirmamentoUsado, onTap: () => _verFirmamento(c.cartaId!)),
          ),
        ],
      ],
    );
  }

  void _verFirmamento(int id) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => FirmamentoDetailScreen(cartaId: id)));

  Widget _pregunta(Consulta c) {
    final estilo = c.modulo.estilo;
    return _Panel(
      titulo: TxConsultas.preguntaTitulo,
      dato: TxConsultas.caracteres('${c.pregunta.length}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '«', style: TextStyle(color: CnsColores.cian.withValues(alpha: .55))),
                TextSpan(text: c.pregunta),
                TextSpan(text: '»', style: TextStyle(color: CnsColores.cian.withValues(alpha: .55))),
              ],
            ),
            style: CnsTipos.serifStyle(size: 20, height: 1.45, color: CnsColores.detalleTitulo),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(nombreModulo(c.modulo), estilo.sello),
              if (c.modeloIa != null) _Chip(c.modeloIa!, CnsColores.cian),
              if (c.fuente != null) _Chip(c.fuente!, CnsColores.cian),
              if (c.desdeCache) const _Chip(TxConsultas.chipCache, CnsColores.oro),
              if (c.usoFirmamento) _Chip(TxConsultas.chipFirmamento, ModuloEstilo.persefone.sello),
            ],
          ),
        ],
      ),
    );
  }

  Widget _respuesta(Consulta c) => _Panel(
        titulo: TxConsultas.respuestaTitulo,
        dato: TxConsultas.caracteres(miles(c.caracteres ?? c.respuesta.length)),
        child: CuerpoMarkdown(texto: c.respuesta, size: 13.5),
      );

  Widget _parametros(Consulta c) => _Panel(
        titulo: TxConsultas.parametrosTitulo,
        dato: TxConsultas.parametrosNota,
        child: Column(
          children: [
            _Dato(TxConsultas.modulo, nombreModulo(c.modulo)),
            _Dato(TxConsultas.proveedor, c.fuente ?? '—'),
            _Dato(TxConsultas.modelo, c.modeloIa ?? '—'),
            _Dato(TxConsultas.desdeCache, c.desdeCache ? TxConsultas.si : TxConsultas.no),
            if (c.tiempoMs != null) _Dato(TxConsultas.tardo, segundos(c.tiempoMs!, decimales: 2)),
            _Dato(TxConsultas.caracteresRotulo, miles(c.caracteres ?? c.respuesta.length)),
            if (c.creada != null) _Dato(TxConsultas.guardada, fechaHora(c.creada!)),
          ],
        ),
      );

  /// Las claves que se pintan como «cielo»; lo demás va a «Contexto enviado».
  static const _claveCielo = {
    'momento', 'hemisferio', 'estacion', 'sol', 'luna', 'planetas_visibles', 'planetas',
    'casa_dominante', 'zodiaco_dominante',
  };

  Widget _cielo(Consulta c) {
    final ctx = c.contexto;
    final sol = ctx['sol'] is Map ? ctx['sol'] as Map : const {};
    final luna = ctx['luna'] is Map ? ctx['luna'] as Map : const {};
    final tieneCielo = ctx.keys.any(_claveCielo.contains);

    return _Panel(
      titulo: TxConsultas.cieloTitulo,
      dato: _momento(ctx['momento']) ?? TxConsultas.sinInstante,
      child: !tieneCielo
          ? const _Vacio(TxConsultas.sinCielo)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (sol.isNotEmpty)
                  _Astro(
                    icono: '☀️',
                    titulo: sol['visible'] == true ? TxConsultas.sobreHorizonte : TxConsultas.bajoHorizonte,
                    detalle: '${sol['constelacion'] ?? TxConsultas.sinConstelacion}',
                  ),
                if (sol['energia'] != null) _Dato(TxConsultas.energia, '${sol['energia']}'),
                if (ctx['estacion'] != null) _Dato(TxConsultas.estacion, _mayuscula('${ctx['estacion']}')),
                if (ctx['hemisferio'] != null) _Dato(TxConsultas.hemisferio, '${ctx['hemisferio']}'),
                if (luna.isNotEmpty)
                  _Astro(
                    icono: '🌙',
                    titulo: '${luna['fase'] ?? TxConsultas.faseNoGuardada}',
                    detalle: luna['iluminacion'] == null
                        ? TxConsultas.iluminacionNoGuardada
                        : TxConsultas.iluminada('${luna['iluminacion']}'),
                  ),
                if (luna['influencia'] != null) _Dato(TxConsultas.influencia, '${luna['influencia']}'),
                if (ctx['zodiaco_dominante'] != null) _Dato(TxConsultas.zodiacoDominante, '${ctx['zodiaco_dominante']}'),
                if (ctx['casa_dominante'] != null) _Dato(TxConsultas.casaDominante, '${ctx['casa_dominante']}'),
                if (c.planetas.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final p in c.planetas) _Chip(p, CnsColores.cian)],
                  ),
                ],
              ],
            ),
    );
  }

  Widget _firmamento(Consulta c) {
    final carta = c.carta ?? const {};
    final titulo = carta['titulo'];
    const ejes = {
      'sun_degree': TxConsultas.ejeSol,
      'moon_degree': TxConsultas.ejeLuna,
      'asc_degree': TxConsultas.ejeAc,
      'mc_degree': TxConsultas.ejeMc,
    };
    return _Panel(
      titulo: TxConsultas.firmamentoUsado,
      dato: titulo is String && titulo.isNotEmpty ? titulo : TxConsultas.firmamentoNumero(c.cartaId ?? '—'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in ejes.entries)
            if (carta[e.key] != null) _Dato(e.value, gradoEnSigno(carta[e.key])),
          const SizedBox(height: 10),
          if (c.cartaId != null)
            Align(
              alignment: Alignment.centerLeft,
              child: _BotonSecundario(texto: TxConsultas.verFirmamentoCompleto, onTap: () => _verFirmamento(c.cartaId!)),
            )
          else
            const _Vacio(TxConsultas.firmamentoInterno),
        ],
      ),
    );
  }

  Widget _contexto(Consulta c) {
    final otros = <String, Object?>{
      for (final e in c.contexto.entries)
        if (!_claveCielo.contains(e.key)) e.key: e.value,
    };
    final filas = aplanar(otros);
    return _Panel(
      titulo: TxConsultas.contextoTitulo,
      dato: c.contexto.isEmpty ? TxConsultas.vacio : TxConsultas.claves(c.contexto.length),
      child: filas.isEmpty
          ? _Vacio(c.contexto.isEmpty ? TxConsultas.sinContexto : TxConsultas.contextoArriba)
          : Column(children: [for (final (r, v) in filas) _Dato(r, v)]),
    );
  }

  static String? _momento(Object? v) {
    final s = int.tryParse('${v ?? ''}');
    if (s != null && s > 100000000) return fechaHora(DateTime.fromMillisecondsSinceEpoch(s * 1000));
    return v?.toString();
  }

  static String _mayuscula(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static const _signos = [
    'Aries', 'Tauro', 'Géminis', 'Cáncer', 'Leo', 'Virgo',
    'Libra', 'Escorpio', 'Sagitario', 'Capricornio', 'Acuario', 'Piscis',
  ];

  /// `123.4` → `3° Leo`.
  static String gradoEnSigno(Object? grado) {
    final g = grado is num ? grado.toDouble() : double.tryParse('$grado');
    if (g == null) return '—';
    final n = g % 360;
    return '${(n % 30).floor()}° ${_signos[(n ~/ 30).clamp(0, 11)]}';
  }

  /// El contexto que no es cielo, aplanado como en la web: «Clima · Temperatura».
  static List<(String, String)> aplanar(Map<String, Object?> datos, [String prefijo = '']) {
    final filas = <(String, String)>[];
    for (final e in datos.entries) {
      final rotulo = [if (prefijo.isNotEmpty) prefijo, _mayuscula(e.key.replaceAll('_', ' '))].join(' · ');
      final v = e.value;
      if (v is Map) {
        if (v.isEmpty) continue;
        filas.addAll(aplanar(v.map((k, x) => MapEntry('$k', x)), rotulo));
      } else if (v is List) {
        if (v.isEmpty) continue;
        if (v.every((x) => x is! Map && x is! List)) {
          filas.add((rotulo, v.map(_valor).join(', ')));
        } else {
          for (final (i, x) in v.indexed) {
            if (x is Map) filas.addAll(aplanar(x.map((k, y) => MapEntry('$k', y)), '$rotulo · ${i + 1}'));
          }
        }
      } else {
        filas.add((rotulo, _valor(v)));
      }
    }
    return filas;
  }

  static String _valor(Object? v) => switch (v) {
        null => '—',
        bool b => b ? TxConsultas.si : TxConsultas.no,
        double d => d.toStringAsFixed(2).replaceAll('.', ','),
        _ => '$v',
      };
}

// ── Piezas del detalle ───────────────────────────────────────────────────────

/// Un panel con cabecera: título a la izquierda y un dato a la derecha
/// (`.cd-panel__top`).
class _Panel extends StatelessWidget {
  const _Panel({required this.titulo, required this.dato, required this.child, this.accion});

  final String titulo;
  final String dato;
  final Widget child;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CnsColores.panel,
        borderRadius: BorderRadius.circular(CnsRadios.panel),
        border: Border.all(color: CnsColores.panelBorde),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [CnsColores.panelTopA, CnsColores.panelTopB]),
              border: Border(bottom: BorderSide(color: CnsColores.panelLinea)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  titulo.toUpperCase(),
                  style: CnsTipos.cejilla(size: 11, tracking: .09, weight: FontWeight.w700, color: CnsColores.cian),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dato,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: CnsColores.datoRotulo),
                  ),
                ),
                if (accion != null) ...[const SizedBox(width: 8), accion!],
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: child),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.rotulo, this.valor);

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CnsColores.datoRotulo)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12.5, color: CnsColores.detalleTexto),
            ),
          ),
        ],
      ),
    );
  }
}

class _Astro extends StatelessWidget {
  const _Astro({required this.icono, required this.titulo, required this.detalle});

  final String icono;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(icono, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CnsColores.detalleTitulo)),
                Text(detalle, style: const TextStyle(fontSize: 11.5, color: CnsColores.datoRotulo)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.texto, this.color);

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CnsRadios.pildora),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(texto, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: CnsColores.detalleTexto)),
          ),
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) =>
      Text(texto, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: CnsColores.slate(.65)));
}

class _BotonPrimario extends StatelessWidget {
  const _BotonPrimario({required this.texto, required this.onTap});

  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: CnsColores.cian.withValues(alpha: .45)),
        gradient: LinearGradient(
          colors: [CnsColores.cian.withValues(alpha: .8), CnsColores.violeta.withValues(alpha: .8)],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(texto, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CnsColores.titulo)),
          ),
        ),
      ),
    );
  }
}

class _BotonSecundario extends StatelessWidget {
  const _BotonSecundario({required this.texto, required this.onTap});

  final String texto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CnsColores.cian.withValues(alpha: .08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: CnsColores.cian.withValues(alpha: .28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(texto, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CnsColores.cian)),
        ),
      ),
    );
  }
}

/// Mis notas: la lista y el campo para agregar (250 como máximo).
class _NotasPanel extends StatefulWidget {
  const _NotasPanel({required this.consulta, required this.service, required this.onNota});

  final Consulta consulta;
  final ConsultasService service;
  final ValueChanged<NotaConsulta> onNota;

  @override
  State<_NotasPanel> createState() => _NotasPanelState();
}

class _NotasPanelState extends State<_NotasPanel> {
  static const _maximo = 250;

  final TextEditingController _texto = TextEditingController();
  bool _abierto = false;
  bool _guardando = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final contenido = _texto.text.trim();
    if (contenido.isEmpty || _guardando) return;
    setState(() => _guardando = true);
    try {
      final nota = await widget.service.agregarNota(widget.consulta.id, contenido);
      if (!mounted) return;
      widget.onNota(nota);
      _texto.clear();
      setState(() => _abierto = false);
    } catch (e) {
      if (mounted) avisoConsola(context, e is ApiException ? e.message : TxConsultas.noSePudoGuardar, error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notas = widget.consulta.notas;
    return _Panel(
      titulo: TxConsultas.notasTitulo,
      dato: '',
      accion: _abierto ? null : _BotonSecundario(texto: TxConsultas.agregar, onTap: () => setState(() => _abierto = true)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_abierto) ...[
            TextField(
              key: const ValueKey('nota-texto'),
              controller: _texto,
              autofocus: true,
              maxLength: _maximo,
              minLines: 2,
              maxLines: 5,
              style: const TextStyle(fontSize: 13.5, color: CnsColores.texto),
              decoration: InputDecoration(
                hintText: TxConsultas.notaPlaceholder,
                hintStyle: TextStyle(fontSize: 13, color: CnsColores.slate(.55)),
                counterStyle: TextStyle(color: CnsColores.slate(.55)),
                filled: true,
                fillColor: CnsColores.pozoHondo,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: CnsColores.slate(.16)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: CnsColores.slate(.16)),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _BotonSecundario(
                  texto: TxConsultas.cancelar,
                  onTap: _guardando ? null : () => setState(() => _abierto = false),
                ),
                const SizedBox(width: 8),
                _BotonPrimario(texto: _guardando ? TxConsultas.guardando : TxConsultas.guardar, onTap: _guardar),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (notas.isEmpty)
            const _Vacio(TxConsultas.sinNotas)
          else
            for (final n in notas)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CnsColores.pozo,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CnsColores.slate(.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.contenido, style: const TextStyle(fontSize: 13.5, height: 1.5, color: CnsColores.detalleTexto)),
                    if (n.creada != null) ...[
                      const SizedBox(height: 4),
                      Text(haceTiempo(n.creada!), style: const TextStyle(fontSize: 10.5, color: CnsColores.datoRotulo)),
                    ],
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/carta.dart';
import '../models/consultas.dart';
import '../services/anuncio_consulta.dart';
import '../services/api_client.dart';
import '../services/astral_chart_service.dart';
import '../services/consultas_service.dart';
import '../textos/consultas_textos.dart';
import '../theme/consultas_theme.dart';
import '../widgets/consultas/cns_basicos.dart';
import '../widgets/consultas/consola_consultas.dart';
import '../widgets/consultas/consulta_card.dart';
import '../widgets/consultas/descargo.dart';
import '../widgets/consultas/fondo_consultas.dart';
import 'consulta_detalle_screen.dart';
import 'create_astral_chart_screen.dart';

/// La pestaña CONSULTAS: la consola de la web (Demeter · Oráculo · Perséfone),
/// el historial con su paginación y el descargo al pie.
class ConsultasScreen extends StatefulWidget {
  const ConsultasScreen({super.key, this.service, this.cartas, this.anuncio});

  /// Para los tests; por defecto, los de [ApiClient.instance].
  final ConsultasService? service;
  final AstralChartService? cartas;
  final AnuncioConsulta? anuncio;

  @override
  State<ConsultasScreen> createState() => _ConsultasScreenState();
}

class _ConsultasScreenState extends State<ConsultasScreen> {
  late final ConsultasService _service = widget.service ?? ConsultasService();
  late final AstralChartService _cartasService = widget.cartas ?? AstralChartService();
  late final AnuncioConsulta _anuncio = widget.anuncio ?? AnuncioConsulta.intersticial();
  final ScrollController _scroll = ScrollController();

  CatalogoConsultas? _catalogo;
  Object? _errorCatalogo;
  ContextoMomento? _contexto;
  List<Carta> _cartas = const [];

  final List<Consulta> _consultas = [];
  int _pagina = 0;
  int _total = 0;
  bool _hayMas = true;
  bool _cargandoHistorial = false;
  bool _errorHistorial = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alDesplazar);
    _anuncio.cargar();
    unawaited(_cargar());
  }

  @override
  void dispose() {
    _anuncio.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _errorCatalogo = null);
    unawaited(_cargarContexto());
    unawaited(_cargarCartas());
    unawaited(_recargarHistorial());
    try {
      final catalogo = await _service.catalogo();
      if (mounted) setState(() => _catalogo = catalogo);
    } catch (e) {
      if (mounted) setState(() => _errorCatalogo = e);
    }
  }

  Future<void> _cargarContexto() async {
    try {
      final contexto = await _service.contexto();
      if (mounted) setState(() => _contexto = contexto);
    } catch (e) {
      // Sin cielo la consola funciona igual, sin franjas.
      debugPrint('Contexto de consultas no disponible (${e.runtimeType}).');
    }
  }

  Future<void> _cargarCartas() async {
    final crudas = await _cartasService.getUserCharts();
    if (!mounted) return;
    setState(() => _cartas = crudas.map(Carta.fromJson).whereType<Carta>().toList());
  }

  Future<void> _recargarHistorial() async {
    _pagina = 0;
    _hayMas = true;
    _consultas.clear();
    await _masHistorial();
  }

  Future<void> _masHistorial() async {
    if (_cargandoHistorial || !_hayMas) return;
    setState(() {
      _cargandoHistorial = true;
      _errorHistorial = false;
    });
    try {
      final pagina = await _service.historial(pagina: _pagina + 1);
      if (!mounted) return;
      setState(() {
        final ids = _consultas.map((c) => c.id).toSet();
        _consultas.addAll(pagina.consultas.where((c) => !ids.contains(c.id)));
        _pagina = pagina.pagina;
        _hayMas = pagina.hayMas;
        _total = pagina.total;
      });
    } catch (_) {
      if (mounted) setState(() => _errorHistorial = true);
    } finally {
      if (mounted) setState(() => _cargandoHistorial = false);
    }
  }

  void _alDesplazar() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels > p.maxScrollExtent - 600) unawaited(_masHistorial());
  }

  Future<void> _crearFirmamento() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateAstralChartScreen()));
    if (mounted) unawaited(_cargarCartas());
  }

  Future<void> _abrir(Consulta c) async {
    final actualizada = await Navigator.of(context).push<Consulta>(MaterialPageRoute(
      builder: (_) => ConsultaDetalleScreen(consultaId: c.id, inicial: c, service: _service),
    ));
    if (actualizada == null || !mounted) return;
    setState(() {
      final i = _consultas.indexWhere((x) => x.id == actualizada.id);
      if (i >= 0) _consultas[i] = actualizada;
    });
  }

  Future<void> _borrar(Consulta c) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CnsColores.hoja,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CnsRadios.resumen),
          side: BorderSide(color: CnsColores.slate(.14)),
        ),
        content: Text(
          TxConsultas.borrarPregunta(c.pregunta),
          style: const TextStyle(fontSize: 14, height: 1.5, color: CnsColores.texto),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(TxConsultas.cancelar, style: TextStyle(color: CnsColores.slate(.8))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(TxConsultas.borrar, style: TextStyle(color: CnsColores.error)),
          ),
        ],
      ),
    );
    if (si != true || !mounted) return;
    try {
      await _service.borrar(c.id);
      if (!mounted) return;
      setState(() {
        _consultas.removeWhere((x) => x.id == c.id);
        _total = (_total - 1).clamp(0, 1 << 30);
      });
      avisoConsola(context, TxConsultas.borrada);
    } catch (e) {
      if (mounted) avisoConsola(context, e is ApiException ? e.message : TxConsultas.noSeBorro, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final telefono = MediaQuery.sizeOf(context).width < CnsEspacios.anchoTelefono;
    final lado = telefono ? CnsEspacios.l : 20.0;

    return FondoConsultas(
      child: RefreshIndicator(
        color: CnsColores.cian,
        backgroundColor: CnsColores.hoja,
        onRefresh: () async {
          unawaited(_cargarContexto());
          unawaited(_cargarCartas());
          await _recargarHistorial();
        },
        child: ListView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(lado, telefono ? 30 : 44, lado, 48),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1248),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _cabecera(),
                    SizedBox(height: telefono ? 28 : 40),
                    _consola(),
                    SizedBox(height: telefono ? 40 : 52),
                    _historial(),
                    const SizedBox(height: CnsEspacios.xxl),
                    const DescargoConsultas(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cabecera() {
    final ctx = _contexto;
    final ahora = DateTime.now();
    final lugar = ctx?.lugar ?? '';
    final datos = [
      '📅 ${ctx?.fecha ?? fechaCorta(ahora)}',
      '🕐 ${ctx?.hora ?? horaCorta(ahora)}',
      if (lugar.isNotEmpty) '📍 ${lugar.length > 26 ? '${lugar.substring(0, 26)}...' : lugar}',
      TxConsultas.archivo(_total, _cartas.length),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(TxConsultas.cejilla.toUpperCase(), style: CnsTipos.cejilla()),
        const SizedBox(height: 10),
        Text(TxConsultas.tituloLinea1, style: CnsTipos.serifStyle(size: 30, height: 1.12)),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => const LinearGradient(
            colors: CnsColores.tituloDegradado,
            stops: [0, .45, 1],
          ).createShader(r),
          child: Text(
            TxConsultas.tituloLinea2,
            style: CnsTipos.serifStyle(size: 30, height: 1.12, style: FontStyle.italic),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          TxConsultas.lema,
          style: TextStyle(fontSize: 14.4, height: 1.7, color: CnsColores.slate300.withValues(alpha: .66)),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final d in datos) Text(d, style: TextStyle(fontSize: 11, color: CnsColores.slate(.6))),
          ],
        ),
      ],
    );
  }

  Widget _consola() {
    final catalogo = _catalogo;
    if (catalogo != null) {
      return ConsolaConsultas(
        catalogo: catalogo,
        contexto: _contexto,
        cartas: _cartas,
        service: _service,
        anuncio: _anuncio,
        onCrearFirmamento: _crearFirmamento,
        onConsultaHecha: () => unawaited(_recargarHistorial()),
      );
    }
    return CnsPunteado(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      radio: CnsRadios.consola,
      child: Center(
        child: _errorCatalogo == null
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: CnsColores.cian))
            : Column(
                children: [
                  Text(
                    _errorCatalogo is ApiException ? (_errorCatalogo as ApiException).message : TxConsultas.catalogoError,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: CnsColores.slate(.8)),
                  ),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _cargar, child: const Text(TxConsultas.reintentar)),
                ],
              ),
      ),
    );
  }

  Widget _historial() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: CnsColores.slate(.12)))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(TxConsultas.historialTitulo, style: CnsTipos.serifStyle(size: 21, color: CnsColores.textoFuerte)),
              ),
              Text(TxConsultas.registros(_total).toUpperCase(), style: CnsTipos.cejilla()),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_consultas.isEmpty && !_cargandoHistorial && !_errorHistorial)
          _vacio()
        else
          LayoutBuilder(builder: (context, c) {
            const gap = 16.0;
            final columnas = (c.maxWidth / (290 + gap)).floor().clamp(1, 4);
            final ancho = (c.maxWidth - gap * (columnas - 1)) / columnas;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final consulta in _consultas)
                  SizedBox(
                    width: ancho,
                    child: ConsultaCard(
                      key: ValueKey('consulta-${consulta.id}'),
                      consulta: consulta,
                      onAbrir: () => _abrir(consulta),
                      onBorrar: () => _borrar(consulta),
                    ),
                  ),
              ],
            );
          }),
        if (_cargandoHistorial)
          const Padding(
            padding: EdgeInsets.all(CnsEspacios.xl),
            child: Center(
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: CnsColores.cian)),
            ),
          ),
        if (_errorHistorial)
          Padding(
            padding: const EdgeInsets.all(CnsEspacios.l),
            child: Column(
              children: [
                Text(TxConsultas.historialError, style: TextStyle(fontSize: 13, color: CnsColores.slate(.75))),
                TextButton(onPressed: _masHistorial, child: const Text(TxConsultas.reintentar)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _vacio() {
    return CnsPunteado(
      radio: CnsRadios.consola,
      fondo: CnsColores.velo,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
      child: Column(
        children: [
          Text(TxConsultas.vacioCejilla.toUpperCase(), style: CnsTipos.cejilla()),
          const SizedBox(height: 10),
          Text(TxConsultas.vacioTitulo, textAlign: TextAlign.center, style: CnsTipos.serifStyle(size: 24)),
          const SizedBox(height: 12),
          Text(
            TxConsultas.vacioTexto,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.4, height: 1.7, color: CnsColores.slate300.withValues(alpha: .66)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/carta.dart';
import '../models/firmamento.dart';
import '../services/api_client.dart';
import '../services/astral_chart_service.dart';
import '../widgets/firmamento/aspectos.dart';
import '../widgets/firmamento/notas.dart';
import '../widgets/firmamento/rueda_natal.dart';
import '../widgets/firmamento/tablas.dart';
import '../widgets/saldo_polvo.dart';

/// Detalle de un firmamento. Se arma solo con `data.firmamento`; de la carta
/// se toman la fecha, la hora y el lugar para la cabecera.
class FirmamentoDetailScreen extends StatefulWidget {
  const FirmamentoDetailScreen({
    super.key,
    required this.cartaId,
    this.carta,
    this.inicial,
    this.service,
  });

  final int cartaId;

  /// La del listado, para la cabecera mientras carga.
  final Carta? carta;

  /// La respuesta del alta (201): se muestra sin pedir otra vez.
  final FirmamentoDetalle? inicial;
  final AstralChartService? service;

  @override
  State<FirmamentoDetailScreen> createState() => _FirmamentoDetailScreenState();
}

class _FirmamentoDetailScreenState extends State<FirmamentoDetailScreen> {
  late final AstralChartService _service = widget.service ?? AstralChartService();

  Firmamento? _f;
  Carta? _carta;
  List<NotaFirmamento> _notas = const [];
  int? _costoIa;
  String? _error;
  bool _recalculando = false;

  // Lo resaltado en la rueda: un planeta o un par.
  String? _cuerpo;
  (String, String)? _par;

  @override
  void initState() {
    super.initState();
    _carta = widget.inicial?.carta ?? widget.carta;
    _f = widget.inicial?.firmamento;
    _notas = widget.inicial?.notas ?? const [];
    _costoIa = widget.inicial?.notaIaCosto;
    if (_f == null) _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final d = await _service.detalle(widget.cartaId);
      if (!mounted) return;
      setState(() {
        _f = d.firmamento;
        _carta = d.carta ?? _carta;
        _notas = d.notas;
        _costoIa = d.notaIaCosto ?? _costoIa;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.statusCode == 404 ? 'Ese firmamento no existe.' : e.message);
    }
  }

  void _tocarCuerpo(String? clave) => setState(() {
        _par = null;
        _cuerpo = clave == _cuerpo ? null : clave;
      });

  void _tocarPar(String a, String b) => setState(() {
        _cuerpo = null;
        _par = _par != null && (_par == (a, b) || _par == (b, a)) ? null : (a, b);
      });

  @override
  Widget build(BuildContext context) {
    final f = _f;
    return Scaffold(
      backgroundColor: kFondo,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: kTexto,
        title: const Text('Firmamento', style: TextStyle(color: kCian, fontWeight: FontWeight.bold)),
        actions: const [SaldoPolvo()],
      ),
      body: f == null
          ? (_error == null
              ? const Center(child: CircularProgressIndicator(color: kCian))
              : _Mensaje(texto: _error!, onReintentar: _cargar))
          : LayoutBuilder(builder: (context, c) => _contenido(f, ancho: c.maxWidth)),
    );
  }

  Widget _contenido(Firmamento f, {required double ancho}) {
    final rueda = _Seccion(
      child: RuedaNatal(firmamento: f, cuerpo: _cuerpo, par: _par, onTocar: _tocarCuerpo),
    );
    final notas = _Seccion(
      titulo: 'Notas',
      child: NotasFirmamento(
        cartaId: widget.cartaId,
        notas: _notas,
        costoIa: _costoIa,
        service: _service,
        onNota: (n) => setState(() => _notas = [n, ..._notas]),
      ),
    );
    final dominantes = _Seccion(titulo: 'Dominantes', subtitulo: 'lo que se mira primero', child: _dominantes(f));
    final posiciones = _Seccion(titulo: 'Posiciones', child: _posiciones(f));
    final aspectos = _Seccion(
      titulo: 'Aspectos',
      child: AspectosFirmamento(firmamento: f, par: _par, onPar: _tocarPar),
    );
    final figuras = _Seccion(titulo: 'Figuras', child: _figuras(f));
    final ejes = _Seccion(titulo: 'Ejes y casas', child: _ejesYCasas(f));
    final reparto = _Seccion(titulo: 'Reparto', child: _reparto(f));
    final solLuna = _Seccion(
      titulo: 'Sol y Luna',
      subtitulo: 'fase y lo que precedió al nacimiento',
      child: _solYLuna(f),
    );
    final calculo = _comoSeCalculo(f);

    final cabecera = <Widget>[
      _cabecera(f),
      if (f.zona.revisar && f.zona.sugerida != null) _avisoZona(f),
    ];

    // En tablet, dos columnas con el par rueda y Dominantes arriba.
    if (ancho >= 720) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          ...cabecera,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: [rueda, notas])),
              const SizedBox(width: 16),
              Expanded(child: dominantes),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: [posiciones, figuras, reparto, calculo])),
              const SizedBox(width: 16),
              Expanded(child: Column(children: [aspectos, ejes, solLuna])),
            ],
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        ...cabecera,
        rueda,
        notas,
        dominantes,
        posiciones,
        aspectos,
        figuras,
        ejes,
        reparto,
        solLuna,
        calculo,
      ],
    );
  }

  // --- Cabecera -----------------------------------------------------------

  Widget _cabecera(Firmamento f) {
    final carta = _carta;
    final partes = <String>[
      if (carta != null && carta.birthDate.isNotEmpty) '${_fecha(carta.birthDate)} ${carta.birthTime}',
      if (f.zona.timezone.isNotEmpty) '${f.zona.timezone} (${f.zona.rotulo})',
      if (carta?.lat != null && carta?.lon != null)
        '${carta!.lat!.toStringAsFixed(2)}°, ${carta.lon!.toStringAsFixed(2)}°',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            carta == null || carta.titulo.isEmpty ? 'Firmamento' : carta.titulo,
            style: const TextStyle(color: kTexto, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(partes.join(' · '), style: const TextStyle(color: kTextoTenue, fontSize: 13)),
          if (_bigThree(f) case final linea?) ...[
            const SizedBox(height: 8),
            Text(linea, style: const TextStyle(color: kTexto, fontSize: 14, height: 1.4)),
          ],
        ],
      ),
    );
  }

  /// «☉ Aries · ☽ Acuario · AC Tauro — Regente: ♀ Venus en Aries, casa XII, exilio».
  String? _bigThree(Firmamento f) {
    final bt = f.natal.bigThree;
    if (bt == null) return null;
    final partes = [
      if (bt.sun != null) '${glifoTexto('☉')} ${signoDe(bt.sun!).nombre}',
      if (bt.moon != null) '${glifoTexto('☽')} ${signoDe(bt.moon!).nombre}',
      if (bt.asc != null) 'AC ${signoDe(bt.asc!).nombre}',
    ];
    final r = f.natal.chartRuler;
    if (r == null) return partes.join(' · ');
    final dig = kDignidades[r.dignity]?.nombre.toLowerCase();
    final regente = '${glifoTexto(f.simbolo(r.body))} ${f.nombre(r.body)} en '
        '${signoDe(r.sign).nombre}, casa ${romano(r.house)}${dig == null ? '' : ', $dig'}';
    return '${partes.join(' · ')} — Regente: $regente';
  }

  Widget _avisoZona(Firmamento f) {
    final z = f.zona;
    final s = z.sugerida!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAmbar.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAmbar.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Este firmamento se calculó con ${z.timezone} (${z.rotulo}), pero en ese lugar y esa '
            'fecha regía ${s.timezone}, ${s.rotulo}. Si la hora se anotó en hora local, el '
            'Ascendente y las casas están corridos.',
            style: const TextStyle(color: kTexto, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            // Desactivado mientras espera: el servidor admite 10 por minuto.
            onPressed: _recalculando ? null : () => _recalcular(s.timezone),
            style: OutlinedButton.styleFrom(
              foregroundColor: kAmbar,
              side: BorderSide(color: kAmbar.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: _recalculando
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: kAmbar),
                  )
                : const Icon(Icons.schedule, size: 18),
            label: Text('Recalcular con ${s.timezone}'),
          ),
        ],
      ),
    );
  }

  Future<void> _recalcular(String timezone) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xEF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Recalcular', style: TextStyle(color: kTexto)),
        content: const Text(
          'El Ascendente y las casas van a cambiar. ¿Recalcular?',
          style: TextStyle(color: kTextoTenue, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: kTextoTenue)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Recalcular', style: TextStyle(color: kCian)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _recalculando = true);
    try {
      final r = await _service.cambiarZona(widget.cartaId, timezone);
      if (!mounted) return;
      setState(() {
        _f = r.detalle.firmamento;
        _carta = r.detalle.carta ?? _carta;
        _cuerpo = null;
        _par = null;
      });
      if (r.message != null) _avisar(r.message!);
    } on ApiException catch (e) {
      // 422 o 429: el mensaje ya viene listo para el usuario.
      if (mounted) _avisar(e.statusCode == 404 ? 'Ese firmamento no existe.' : e.message, error: true);
    } finally {
      if (mounted) setState(() => _recalculando = false);
    }
  }

  void _avisar(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: error ? Colors.redAccent : Colors.green),
    );
  }

  // --- Dominantes ---------------------------------------------------------

  Widget _dominantes(Firmamento f) {
    final n = f.natal;
    final reparto = f.reparto;
    Color colorDe(List<RepartoItem>? items, String nombre) =>
        items?.where((i) => i.nombre == nombre).firstOrNull?.color ?? kTexto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Subtitulo('Planetas angulares'),
        if (n.angulares.isEmpty)
          const _Tenue('Ningún planeta a menos de 8° de un eje.')
        else
          for (final a in n.angulares)
            _Linea([
              _glifo(f, a.body),
              TextSpan(text: ' ${f.nombre(a.body)} sobre el ${kEjes[a.angle]?.sigla ?? a.angle}'),
              TextSpan(text: ' · ${gradoMinutos(a.distance)}', style: const TextStyle(color: kTextoTenue)),
            ]),
        const _Subtitulo('Aspectos más cerrados'),
        for (final a in n.cerrados)
          _Linea([
            _glifo(f, a.a),
            TextSpan(text: ' ${glifoTexto(a.simbolo)} ', style: TextStyle(color: a.color)),
            _glifo(f, a.b),
            TextSpan(text: '  ${f.nombre(a.a)} ${a.nombre} ${f.nombre(a.b)}'),
            TextSpan(
              text: ' · ${a.orbeDm} ${a.aplicativo ? 'a' : 's'}',
              style: const TextStyle(color: kTextoTenue),
            ),
          ]),
        if (f.figuras.isNotEmpty) ...[
          const _Subtitulo('Figuras'),
          for (final fig in f.figuras)
            _Linea([
              TextSpan(text: fig.etiqueta, style: TextStyle(color: fig.color, fontWeight: FontWeight.w600)),
              if (fig.detalle != null)
                TextSpan(text: ' · ${fig.detalle}', style: const TextStyle(color: kTextoTenue)),
            ]),
        ],
        if (n.dominante case final d?) ...[
          const _Subtitulo('Elemento y modalidad'),
          _Linea([
            TextSpan(text: d.element, style: TextStyle(color: colorDe(reparto?.elementos, d.element))),
            const TextSpan(text: ' · '),
            TextSpan(text: d.modality, style: TextStyle(color: colorDe(reparto?.modalidades, d.modality))),
          ]),
        ],
        if (n.masFuerte case final m?) ...[
          const _Subtitulo('Planeta más fuerte'),
          _Linea([
            _glifo(f, m.body),
            TextSpan(text: ' ${f.nombre(m.body)}'),
            TextSpan(
              text: [
                for (final r in m.reasons) r == 'angular' ? 'angular' : (kDignidades[r]?.nombre.toLowerCase() ?? r),
                m.aspects == 1 ? '1 aspecto mayor' : '${m.aspects} aspectos mayores',
              ].map((t) => ' · $t').join(),
              style: const TextStyle(color: kTextoTenue),
            ),
          ]),
        ],
      ],
    );
  }

  // --- Posiciones ---------------------------------------------------------

  Widget _posiciones(Firmamento f) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in f.cuerpos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 26,
                  child: Text(glifoTexto(c.simbolo), style: TextStyle(color: c.color, fontSize: 17)),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        c.nombre,
                        style: TextStyle(
                          color: c.esPunto ? kTextoTenue : kTexto,
                          fontStyle: c.esPunto ? FontStyle.italic : FontStyle.normal,
                          fontSize: 13,
                        ),
                      ),
                      if (kDignidades[c.dignidad] case final d?)
                        _Badge(c.dignidadModerna ? '(${d.nombre})' : d.nombre, d.color, tenue: c.dignidadModerna),
                      if (c.retrogrado) const _Badge('R', kColorR),
                      if (c.estacionario) const _Badge('E', kColorE),
                      if (c.fueraDeLimites) const _Badge('OOB', kColorOob),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: glifoTexto(signoDe(c.signo).glifo), style: TextStyle(color: signoDe(c.signo).color)),
                    TextSpan(text: ' ${gradoMinutos(c.gradoEnSigno)}'),
                  ]),
                  style: const TextStyle(color: kTexto, fontSize: 13),
                ),
                SizedBox(
                  width: 40,
                  child: Text(romano(c.casa),
                      textAlign: TextAlign.right, style: const TextStyle(color: kTextoTenue, fontSize: 12)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        const _Tenue('R retrógrado · E estacionario · OOB fuera de límites (declinación mayor que la '
            'del Sol en el solsticio). Entre paréntesis, la regencia moderna.'),
      ],
    );
  }

  // --- Figuras ------------------------------------------------------------

  Widget _figuras(Firmamento f) {
    if (f.figuras.isEmpty) {
      return const _Tenue('Ninguna figura: no hay gran trígono, cruz, T, yod, cometa, rectángulo ni tensión angular.');
    }
    return Column(
      children: [
        for (final fig in f.figuras)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: fig.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: fig.color.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(fig.etiqueta,
                          style: TextStyle(color: fig.color, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    Text.rich(TextSpan(children: [for (final k in fig.cuerpos) _glifo(f, k, espacio: true)]),
                        style: const TextStyle(fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  fig.detalle ?? fig.cuerpos.map(f.nombre).join(', '),
                  style: const TextStyle(color: kTexto, fontSize: 13),
                ),
                if (fig.asociados.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _Tenue('asociados por conjunción: ${fig.asociados.map(f.nombre).join(', ')}'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // --- Ejes y casas -------------------------------------------------------

  Widget _ejesYCasas(Firmamento f) {
    final regentes = f.natal.regentesCasas;
    String posicion(double lon) {
      final sig = signoDe(lon ~/ 30);
      return '${glifoTexto(sig.glifo)} ${gradoMinutos(lon % 30)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final k in const ['asc', 'mc', 'dsc', 'ic'])
          if (f.ejes[k] case final e?)
            _Linea([
              TextSpan(text: '${kEjes[k]!.sigla} ', style: TextStyle(color: kEjes[k]!.color, fontWeight: FontWeight.bold)),
              TextSpan(text: '${kEjes[k]!.nombre}  '),
              TextSpan(text: posicion(e.longitud), style: TextStyle(color: signoDe(e.signo).color)),
            ]),
        if (f.cuspides.length == 12) ...[
          const SizedBox(height: 8),
          for (var i = 0; i < 12; i++)
            _Linea([
              TextSpan(text: romano(i + 1).padRight(5), style: const TextStyle(color: kTextoTenue)),
              TextSpan(text: posicion(f.cuspides[i])),
              if (regentes.length == 12 && regentes[i] != null) ...[
                TextSpan(text: ' · regente ', style: const TextStyle(color: kTextoTenue)),
                _glifo(f, regentes[i]!.ruler),
                TextSpan(text: ' en ${romano(regentes[i]!.house)}'),
                if (regentes[i]!.modern case final m?) ...[
                  const TextSpan(text: ' ('),
                  _glifo(f, m),
                  TextSpan(text: ' en ${romano(f.cuerpo(m)?.casa ?? 0)})', style: const TextStyle(color: kTextoTenue)),
                ],
              ],
            ]),
        ],
        const SizedBox(height: 6),
        if (f.sistemaCasas.isNotEmpty) _Tenue('Cúspides por ${f.sistemaCasas}.'),
      ],
    );
  }

  // --- Reparto ------------------------------------------------------------

  Widget _reparto(Firmamento f) {
    final r = f.reparto;
    final n = f.natal;
    Widget barras(String titulo, List<RepartoItem> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Subtitulo(titulo),
            for (final it in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(it.nombre, style: TextStyle(color: it.color, fontSize: 13)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          children: [
                            Container(height: 8, color: Colors.white.withValues(alpha: 0.05)),
                            FractionallySizedBox(
                              widthFactor: it.frac,
                              child: Container(height: 8, color: it.color.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 66,
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: _numero(it.weight), style: const TextStyle(color: kTexto)),
                          TextSpan(text: '  (${it.count})', style: const TextStyle(color: kTextoTenue)),
                        ]),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r == null)
          const _Tenue('El reparto por elementos necesita el cálculo completo.')
        else ...[
          barras('Elementos', r.elementos),
          barras('Modalidades', r.modalidades),
          const _Tenue('Ponderado; entre paréntesis, el conteo simple de los 10 planetas.'),
        ],
        if (n.secta case final s?) ...[
          const _Subtitulo('Secta'),
          _Linea([
            TextSpan(text: s.type == 'nocturnal' ? 'Carta nocturna' : 'Carta diurna'),
            const TextSpan(text: ' · luminar de la secta: ', style: TextStyle(color: kTextoTenue)),
            _glifo(f, s.luminary),
            TextSpan(text: ' ${f.nombre(s.luminary)}'),
          ]),
        ],
        if (n.hemisferios case final h?) ...[
          const _Subtitulo('Hemisferios'),
          _Linea([
            TextSpan(text: 'Sobre el horizonte ${h.above} · Bajo el horizonte ${h.below}'),
          ]),
          _Linea([TextSpan(text: 'Este ${h.east} · Oeste ${h.west}')]),
          _Tenue('Por casa, con los mismos ${h.total} planetas.'),
        ],
      ],
    );
  }

  // --- Sol y Luna ---------------------------------------------------------

  Widget _solYLuna(Firmamento f) {
    final luna = f.luna;
    final n = f.natal;

    Widget astro(String clave) {
      final c = f.cuerpo(clave);
      if (c == null) return const SizedBox.shrink();
      final sig = signoDe(c.signo);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: glifoTexto(c.simbolo), style: TextStyle(color: c.color)),
                TextSpan(text: ' ${c.nombre} en '),
                TextSpan(text: '${glifoTexto(sig.glifo)} ${sig.nombre}', style: TextStyle(color: sig.color)),
                TextSpan(text: ' ${gradoMinutos(c.gradoEnSigno)} · casa ${romano(c.casa)}'),
              ]),
              style: const TextStyle(color: kTexto, fontSize: 13),
            ),
            if (kDignidades[c.dignidad] case final d?) _Badge(d.nombre, d.color),
          ],
        ),
      );
    }

    Widget prenatal(String titulo, Prenatal? p) {
      if (p == null) return const SizedBox.shrink();
      final sig = signoDe(p.signo);
      // El instante llega en UTC: se muestra en la zona del firmamento.
      final fecha = DateTime.fromMillisecondsSinceEpoch((p.timestamp + f.zona.desfase) * 1000, isUtc: true);
      return _Linea([
        TextSpan(text: '$titulo: ', style: const TextStyle(color: kTextoTenue)),
        TextSpan(text: '${glifoTexto(sig.glifo)} ${gradoMinutos(p.longitud % 30)}', style: TextStyle(color: sig.color)),
        TextSpan(text: ' ${sig.nombre} · casa ${romano(p.casa)} · ${_dosDigitos(fecha.day)}/'
            '${_dosDigitos(fecha.month)}/${fecha.year}'),
      ]);
    }

    final eclipse = n.eclipseSolar, eclipseL = n.eclipseLunar;
    String tipo(Prenatal? p) {
      final t = kTipoEclipse[p?.label ?? p?.type];
      return t == null ? '' : ' ($t)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        astro('sun'),
        astro('moon'),
        if (luna != null) ...[
          const _Subtitulo('Fase lunar'),
          Text(kRudhyar[luna.rudhyar] ?? luna.rudhyar,
              style: const TextStyle(color: kTexto, fontSize: 18, fontWeight: FontWeight.bold)),
          if (luna.iluminacion != null) _Tenue('${luna.iluminacion!.round()} % iluminada'),
        ],
        if (n.lunacion != null || eclipse != null || eclipseL != null) ...[
          const _Subtitulo('Antes del nacimiento'),
          prenatal(n.lunacion?.type == 'new' ? 'Luna nueva prenatal' : 'Luna llena prenatal', n.lunacion),
          prenatal('Eclipse de Sol prenatal${tipo(eclipse)}', eclipse),
          prenatal('Eclipse de Luna prenatal${tipo(eclipseL)}', eclipseL),
          _Tenue('La lunación y los eclipses son los últimos anteriores al nacimiento; casa en esta '
              'carta, fecha en ${f.zona.timezone}.'),
        ],
      ],
    );
  }

  // --- Cómo se calculó ----------------------------------------------------

  Widget _comoSeCalculo(Firmamento f) {
    final z = f.zona;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _cajaTarjeta,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: kTextoTenue,
          collapsedIconColor: kTextoTenue,
          title: const Text('Cómo se calculó',
              style: TextStyle(color: kCian, fontWeight: FontWeight.bold, fontSize: 15)),
          children: [
            _Linea([
              const TextSpan(text: 'Zona horaria: ', style: TextStyle(color: kTextoTenue)),
              TextSpan(text: '${z.timezone} (${z.rotulo})${z.horarioVerano ? ' · horario de verano' : ''}'),
            ]),
            _Linea([
              const TextSpan(text: 'Casas: ', style: TextStyle(color: kTextoTenue)),
              TextSpan(text: '${f.sistemaCasas} · zodiaco tropical'),
            ]),
            const _Linea([
              TextSpan(text: 'Efemérides: ', style: TextStyle(color: kTextoTenue)),
              TextSpan(text: 'VSOP87 · Plutón y Quirón de JPL Horizons'),
            ]),
            if (f.orbes.isNotEmpty) ...[
              const _Subtitulo('Orbes por aspecto y clase de cuerpo'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _tablaOrbes(f),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tablaOrbes(Firmamento f) {
    const celda = EdgeInsets.symmetric(horizontal: 8, vertical: 5);
    const tenue = TextStyle(color: kTextoTenue, fontSize: 11);
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder.all(color: Colors.white.withValues(alpha: 0.06)),
      children: [
        TableRow(children: [
          const Padding(padding: celda, child: Text('Aspecto', style: tenue)),
          for (final c in f.clasesOrbe)
            Padding(padding: celda, child: Text(c, style: tenue, textAlign: TextAlign.center)),
        ]),
        for (final o in f.orbes)
          TableRow(children: [
            Padding(
              padding: celda,
              child: Text('${glifoTexto(o.simbolo)} ${o.nombre}', style: const TextStyle(color: kTexto, fontSize: 12)),
            ),
            for (var i = 0; i < f.clasesOrbe.length; i++)
              Padding(
                padding: celda,
                child: Text(i < o.orbes.length ? '${_numero(o.orbes[i])}°' : '—',
                    textAlign: TextAlign.center, style: const TextStyle(color: kTexto, fontSize: 12)),
              ),
          ]),
      ],
    );
  }

  TextSpan _glifo(Firmamento f, String clave, {bool espacio = false}) => TextSpan(
        text: '${glifoTexto(f.simbolo(clave))}${espacio ? ' ' : ''}',
        style: TextStyle(color: f.color(clave)),
      );
}

String _dosDigitos(int n) => n.toString().padLeft(2, '0');

String _fecha(String iso) {
  final p = iso.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
}

// 7 → «7», 0.5 → «0,5».
String _numero(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1).replaceAll('.', ',');

final _cajaTarjeta = BoxDecoration(
  color: kTarjeta,
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
);

/// Tarjeta de sección, con el estilo de las del listado.
class _Seccion extends StatelessWidget {
  const _Seccion({this.titulo, this.subtitulo, required this.child});

  final String? titulo;
  final String? subtitulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cajaTarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titulo != null) ...[
            Text(titulo!, style: const TextStyle(color: kCian, fontWeight: FontWeight.bold, fontSize: 15)),
            if (subtitulo != null)
              Text(subtitulo!, style: const TextStyle(color: kTextoTenue, fontSize: 12)),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class _Subtitulo extends StatelessWidget {
  const _Subtitulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(texto, style: const TextStyle(color: kVioleta, fontWeight: FontWeight.bold, fontSize: 13)),
      );
}

class _Tenue extends StatelessWidget {
  const _Tenue(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) =>
      Text(texto, style: const TextStyle(color: kTextoTenue, fontSize: 11.5, height: 1.35));
}

class _Linea extends StatelessWidget {
  const _Linea(this.partes);

  final List<InlineSpan> partes;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text.rich(TextSpan(children: partes), style: const TextStyle(color: kTexto, fontSize: 13, height: 1.35)),
      );
}

/// Badge de dignidad o de estado (R, E, OOB).
class _Badge extends StatelessWidget {
  const _Badge(this.texto, this.color, {this.tenue = false});

  final String texto;
  final Color color;
  final bool tenue;

  @override
  Widget build(BuildContext context) {
    final c = tenue ? color.withValues(alpha: 0.6) : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(texto, style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.bold)),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.texto, required this.onReintentar});

  final String texto;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: kTextoTenue, size: 40),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: kTexto, fontSize: 14)),
            const SizedBox(height: 12),
            TextButton(onPressed: onReintentar, child: const Text('Reintentar', style: TextStyle(color: kCian))),
          ],
        ),
      ),
    );
  }
}

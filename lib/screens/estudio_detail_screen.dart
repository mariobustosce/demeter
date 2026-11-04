import 'package:flutter/material.dart';

import '../models/estudio_detalle.dart';
import '../models/observatorio.dart';
import '../services/api_client.dart';
import '../services/observatorio_service.dart';
import '../widgets/firmamento/tablas.dart';
import '../widgets/observatorio/rango_diario.dart';
import '../widgets/observatorio/wmo.dart';

const Map<String, String> _turnos = {
  'manana': 'Mañana',
  'dia': 'Día',
  'tarde': 'Tarde',
  'noche': 'Noche',
};

const Map<String, ({String icono, String nombre})> _estaciones = {
  'primavera': (icono: '🌸', nombre: 'Primavera'),
  'verano': (icono: '☀️', nombre: 'Verano'),
  'otono': (icono: '🍂', nombre: 'Otoño'),
  'invierno': (icono: '❄️', nombre: 'Invierno'),
};

// Columnas del panel de astros: Sol, Luna, los 7 planetas, Plutón y Quirón.
const List<(String, String)> _astros = [
  ('sun', '☉'), ('moon', '☽'), ('mercury', '☿'), ('venus', '♀'), ('mars', '♂'),
  ('jupiter', '♃'), ('saturn', '♄'), ('uranus', '♅'), ('neptune', '♆'),
  ('pluto', '♇'), ('chiron', '⚷'),
];

/// Detalle de un Estudio del cielo: cabecera, resumen de 14 días, capturas
/// y astros por captura. Uno en pausa o huérfano se lee igual.
class EstudioDetailScreen extends StatefulWidget {
  const EstudioDetailScreen({super.key, required this.estudio, this.precioDescarga = 0, this.service});

  /// El de la tarjeta: se muestra mientras carga la cabecera completa.
  final Estudio estudio;
  final int precioDescarga;
  final ObservatorioService? service;

  @override
  State<EstudioDetailScreen> createState() => _EstudioDetailScreenState();
}

class _EstudioDetailScreenState extends State<EstudioDetailScreen> {
  late final ObservatorioService _service = widget.service ?? ObservatorioService();

  late Estudio _estudio = widget.estudio;
  ResumenEstudio? _resumen;
  final List<Captura> _capturas = [];
  PaginaCapturas? _pagina;
  String? _error;
  bool _cargandoMas = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final id = widget.estudio.id;
      final r = await Future.wait([_service.estudio(id), _service.resumen14(id), _service.capturas(id)]);
      if (!mounted) return;
      final pagina = r[2] as PaginaCapturas;
      setState(() {
        _estudio = r[0] as Estudio;
        _resumen = r[1] as ResumenEstudio;
        _pagina = pagina;
        _capturas
          ..clear()
          ..addAll(pagina.capturas);
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.statusCode == 404 ? 'Ese estudio no existe.' : e.message);
    }
  }

  Future<void> _cargarMas() async {
    final p = _pagina;
    if (p == null || !p.hayMas || _cargandoMas) return;
    setState(() => _cargandoMas = true);
    try {
      final sig = await _service.capturas(widget.estudio.id, pagina: p.pagina + 1);
      if (!mounted) return;
      setState(() {
        _pagina = sig;
        _capturas.addAll(sig.capturas);
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kFondo,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: kTexto,
        title: const Text('Estudio del cielo', style: TextStyle(color: kCian, fontWeight: FontWeight.bold)),
      ),
      body: _resumen == null
          ? (_error == null
              ? const Center(child: CircularProgressIndicator(color: kCian))
              : _Mensaje(texto: _error!, onReintentar: _cargar))
          : RefreshIndicator(
              color: kCian,
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  _cabecera(),
                  _Seccion(titulo: 'Últimos ${_resumen!.diasVentana} días', child: _resumenDe(_resumen!)),
                  _Seccion(
                    titulo: 'Capturas',
                    subtitulo: 'en la hora local del lugar',
                    child: _listaCapturas(),
                  ),
                  _astrosPorCaptura(),
                  const _Seccion(titulo: 'Claves del JSON', child: _Leyenda()),
                ],
              ),
            ),
    );
  }

  // --- Cabecera -----------------------------------------------------------

  Widget _cabecera() {
    final e = _estudio;
    final rango = e.primeraCaptura == null
        ? null
        : '${_fechaIso(e.primeraCaptura!)} – ${_fechaIso(e.ultimaCaptura ?? e.primeraCaptura!)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e.titulo, style: const TextStyle(color: kTexto, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            [
              e.activo ? 'Activo · capturando hasta el ${_fecha(e.expira)}' : 'En pausa',
              ?rango,
              e.capturas == 1 ? '1 captura' : '${e.capturas} capturas',
            ].join(' · '),
            style: const TextStyle(color: kTextoTenue, fontSize: 13),
          ),
          if (!e.activo) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kAmbar.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kAmbar.withValues(alpha: 0.4)),
              ),
              child: const Text(
                '⏸️ La captura está en pausa: renueva para reanudar la captura. Todo lo capturado '
                'sigue aquí, legible y descargable.',
                style: TextStyle(color: kTexto, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Resumen de 14 días -------------------------------------------------

  Widget _resumenDe(ResumenEstudio r) {
    String n(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    final ll = r.lluvia;
    final pr = r.presion;
    final flecha = switch (pr?.dir) { 'sube' => '↑ subiendo', 'baja' => '↓ bajando', _ => '→ estable' };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.resumen.isNotEmpty)
          Text(r.resumen, style: const TextStyle(color: kTexto, fontSize: 14, height: 1.4)),
        if (!r.hayClima)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: _Tenue('Todavía no hay clima capturado en estos días: los gráficos aparecen con la primera captura.'),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Kpi('Máxima', r.max == null ? '—' : '${n(r.max!.v)} °C', r.max?.fecha),
            _Kpi('Mínima', r.min == null ? '—' : '${n(r.min!.v)} °C', r.min?.fecha),
            _Kpi(
              'Lluvia total',
              ll == null ? '—' : '${ll.aprox ? 'aprox. ' : ''}${n(ll.mm)} mm',
              ll == null ? null : (ll.dias == 1 ? '1 día con lluvia' : '${ll.dias} días con lluvia'),
            ),
            _Kpi(
              'Presión · 24 h',
              pr == null ? '—' : flecha,
              pr == null
                  ? 'sin datos suficientes'
                  : '${pr.delta >= 0 ? '+' : ''}${n(pr.delta)} hPa${pr.hpa == null ? '' : ' · ahora ${pr.hpa!.round()} hPa'}',
            ),
          ],
        ),
        if (r.cobertura case final c?) ...[
          const SizedBox(height: 10),
          _Tenue('${c.n} de ${c.total} turnos con clima (${c.pct} %)'),
        ],
        if (r.dias.isNotEmpty) ...[
          const _Subtitulo('Temperatura · rango de cada día'),
          RangoDiario(dias: r.dias),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              const _Leyendita(kTonoNormal, 'Mín. a máx. del día'),
              if (r.hayNormal) ...[
                _Leyendita(kTextoTenue.withValues(alpha: 0.4), 'Normal'),
                const _Leyendita(kTonoCalido, 'Sobre lo normal'),
                const _Leyendita(kTonoFresco, 'Bajo lo normal'),
              ],
              const _Leyendita(kColorLluvia, 'Lluvia del día'),
            ],
          ),
          if (r.dias.every((d) => d.normal == null))
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: _Tenue('La normal del lugar aún se está calculando.'),
            ),
        ],
      ],
    );
  }

  // --- Capturas -----------------------------------------------------------

  Widget _listaCapturas() {
    if (_capturas.isEmpty) {
      return const _Tenue('Aún no hay capturas: la primera llega en el próximo turno (07, 13, 19 o 01 h, '
          'hora local del lugar).');
    }
    // Agrupadas por día (el más reciente primero) y, dentro, por hora.
    final dias = <String, List<Captura>>{};
    for (final c in _capturas) {
      dias.putIfAbsent(c.fechaLocal, () => []).add(c);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in dias.entries) _dia(e.key, e.value..sort((a, b) => (a.horaLocal ?? '').compareTo(b.horaLocal ?? ''))),
        if (_pagina?.hayMas == true)
          Center(
            child: TextButton(
              onPressed: _cargandoMas ? null : _cargarMas,
              child: _cargandoMas
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kCian))
                  : const Text('Cargar más', style: TextStyle(color: kCian)),
            ),
          ),
      ],
    );
  }

  Widget _dia(String fecha, List<Captura> turnos) {
    final est = _estaciones[turnos.first.estacion];
    // El UV es el máximo del día: se lee del turno de día primero, y va una vez.
    final ordenUv = [...turnos.where((t) => t.turno == 'dia'), ...turnos.where((t) => t.turno != 'dia')];
    final uv = ordenUv.map((t) => t.clima?.uv).whereType<double>().firstOrNull;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(_fechaIso(fecha), style: const TextStyle(color: kVioleta, fontWeight: FontWeight.bold, fontSize: 13)),
              if (est != null)
                Text('${est.icono} ${est.nombre}', style: const TextStyle(color: kTextoTenue, fontSize: 12)),
              if (uv != null) Text('UV máx. del día ${_n(uv, 0)}', style: const TextStyle(color: kTextoTenue, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          for (final t in turnos) _turno(t),
        ],
      ),
    );
  }

  Widget _turno(Captura t) {
    final c = t.clima;
    final nombre = '${_turnos[t.turno] ?? t.turno}${t.horaLocal == null ? '' : ' (${t.horaLocal})'}';
    final lluvia = c?.p6 ?? c?.pp;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(nombre, style: const TextStyle(color: kTexto, fontSize: 13)),
          ),
          Icon(c == null ? Icons.remove : iconoWmo(c.wmo, deDia: c.dia), size: 18, color: kCian),
          const SizedBox(width: 8),
          Expanded(
            child: c == null
                // Sin clima: guiones, sin interpolar.
                ? const Text('— sin clima', style: TextStyle(color: kTextoTenue, fontSize: 13))
                : Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    children: [
                      _v('${_n(c.t, 1)} °C', fuerte: true),
                      if (c.st != null) _v('ST ${_n(c.st, 1)}°'),
                      _v('${_n(c.vv, 0)} km/h${c.vr == null ? '' : ' · ráf. ${_n(c.vr, 0)}'}'),
                      _v('${_n(c.h, 0)} %'),
                      if (t.puntoRocio != null) _v('rocío ${_n(t.puntoRocio, 1)}°'),
                      _v('${_n(lluvia, 1)} mm${c.p6 != null ? ' 6 h' : ''}'),
                      _v('${_n(c.pr, 0)} hPa'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _v(String t, {bool fuerte = false}) => Text(
        t,
        style: TextStyle(
          color: fuerte ? kTexto : kTextoTenue,
          fontSize: fuerte ? 13 : 12,
          fontWeight: fuerte ? FontWeight.bold : FontWeight.normal,
        ),
      );

  // --- Astros por captura -------------------------------------------------

  Widget _astrosPorCaptura() {
    // Plutón y Quirón solo si alguna captura los trae.
    final columnas = [
      for (final a in _astros)
        if (!(a.$1 == 'pluto' || a.$1 == 'chiron') || _capturas.any((c) => c.astros.containsKey(a.$1))) a,
    ];
    const celda = EdgeInsets.symmetric(horizontal: 6, vertical: 5);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _caja,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: kTextoTenue,
          collapsedIconColor: kTextoTenue,
          title: const Text('Astros por captura',
              style: TextStyle(color: kCian, fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: const Text('signo y altura sobre el horizonte · atenuado: bajo el horizonte',
              style: TextStyle(color: kTextoTenue, fontSize: 12)),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                children: [
                  TableRow(children: [
                    const SizedBox.shrink(),
                    for (final a in columnas)
                      Padding(
                        padding: celda,
                        child: Text(glifoTexto(a.$2),
                            textAlign: TextAlign.center, style: const TextStyle(color: kTexto, fontSize: 15)),
                      ),
                  ]),
                  for (final c in _capturas)
                    TableRow(children: [
                      Padding(
                        padding: celda,
                        child: Text('${_fechaIso(c.fechaLocal).substring(0, 5)} ${_turnos[c.turno] ?? c.turno}',
                            style: const TextStyle(color: kTextoTenue, fontSize: 11)),
                      ),
                      for (final a in columnas) Padding(padding: celda, child: _celdaAstro(c.astros[a.$1])),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _celdaAstro(AstroCaptura? a) {
    if (a == null) {
      return const Text('—', textAlign: TextAlign.center, style: TextStyle(color: kTextoTenue, fontSize: 11));
    }
    final sig = signoDe(a.signo);
    final alfa = a.sobreHorizonte ? 1.0 : 0.4;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: glifoTexto(sig.glifo), style: TextStyle(color: sig.color.withValues(alpha: alfa))),
        TextSpan(
          text: ' ${a.altura == null ? '—' : '${a.altura!.round()}°'}',
          style: TextStyle(color: kTexto.withValues(alpha: alfa)),
        ),
        if (a.retrogrado) TextSpan(text: ' ℞', style: TextStyle(color: kColorR.withValues(alpha: alfa))),
      ]),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 11),
    );
  }
}

String _n(double? v, int dec) => v == null ? '—' : v.toStringAsFixed(dec).replaceAll('.', ',');

String _fecha(DateTime? f) {
  if (f == null) return '—';
  final l = f.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
}

String _fechaIso(String iso) {
  final p = iso.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
}

final _caja = BoxDecoration(
  color: kTarjeta,
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
);

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, this.subtitulo, required this.child});

  final String titulo;
  final String? subtitulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: _caja,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(color: kCian, fontWeight: FontWeight.bold, fontSize: 15)),
          if (subtitulo != null) Text(subtitulo!, style: const TextStyle(color: kTextoTenue, fontSize: 12)),
          const SizedBox(height: 10),
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
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(texto, style: const TextStyle(color: kVioleta, fontWeight: FontWeight.bold, fontSize: 13)),
      );
}

class _Tenue extends StatelessWidget {
  const _Tenue(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) =>
      Text(texto, style: const TextStyle(color: kTextoTenue, fontSize: 12, height: 1.35));
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.titulo, this.valor, this.detalle);

  final String titulo;
  final String valor;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(color: kTextoTenue, fontSize: 11)),
          const SizedBox(height: 2),
          Text(valor, style: const TextStyle(color: kTexto, fontSize: 16, fontWeight: FontWeight.bold)),
          if (detalle != null && detalle!.isNotEmpty)
            Text(detalle!, style: const TextStyle(color: kTextoTenue, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Leyendita extends StatelessWidget {
  const _Leyendita(this.color, this.texto);

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text(texto, style: const TextStyle(color: kTextoTenue, fontSize: 11)),
        ],
      );
}

/// Las claves del JSON compacto, las mismas que trae la exportación.
class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Tenue('clima: t °C · h humedad % · n nubosidad % · vv viento km/h · vd dirección de donde viene ° · '
            'pp precipitación del instante mm · pr presión hPa · wmo código · dia 1 = de día · uv índice UV '
            'máximo del día (pronóstico) · st sensación térmica °C · vr ráfagas km/h · p6 lluvia de las 6 h previas mm'),
        SizedBox(height: 6),
        _Tenue('astro, por cuerpo: lon longitud eclíptica · sg índice de signo 0-11 · az azimut ° · alt altura ° · '
            'sh 1 = sobre el horizonte · r 1 = retrógrado · v velocidad °/día; sal/pue/cul en timestamp UTC'),
        SizedBox(height: 6),
        _Tenue('estacion: estación astronómica del lugar por el Sol y el hemisferio: primavera · verano · otono · invierno'),
      ],
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

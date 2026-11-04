import 'package:flutter/material.dart';

import '../models/observatorio.dart';
import '../services/api_client.dart';
import '../services/coin_balance.dart';
import '../services/observatorio_service.dart';
import '../widgets/firmamento/tablas.dart';
import '../widgets/observatorio/wmo.dart';

/// Cielos: el clima de ahora de cada favorito y su Estudio del cielo.
class CielosScreen extends StatefulWidget {
  const CielosScreen({super.key, this.service, this.onVerEstudio});

  /// Para los tests; por defecto, el de [ApiClient.instance].
  final ObservatorioService? service;

  /// Abre el detalle de un estudio, con los precios vigentes.
  final void Function(Estudio estudio, Observatorio datos)? onVerEstudio;

  @override
  State<CielosScreen> createState() => _CielosScreenState();
}

class _CielosScreenState extends State<CielosScreen> {
  late final ObservatorioService _service = widget.service ?? ObservatorioService();

  Observatorio? _datos;
  String? _error;

  /// El favorito (contratar) o el estudio (renovar) que está pagando.
  String? _ocupado;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final datos = await _service.resumen();
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  String _conPrecio(String texto, int precio, {String sufijo = ''}) =>
      precio > 0 ? '$texto · $precio ✨$sufijo' : texto;

  Future<bool> _confirmar(String titulo, String texto, String boton) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xEF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(titulo, style: const TextStyle(color: kTexto)),
        content: Text(texto, style: const TextStyle(color: kTextoTenue, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: kTextoTenue)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(boton, style: const TextStyle(color: kCian)),
          ),
        ],
      ),
    );
    return ok == true && mounted;
  }

  Future<void> _contratar(LugarCielo lugar) async {
    final precio = _datos?.precioEstudio ?? 0;
    final texto = precio > 0
        ? 'El Estudio del cielo guarda clima y astros 4 veces al día durante un año. '
            'Cuesta $precio ✨. ¿Contratar?'
        : 'El Estudio del cielo guarda clima y astros 4 veces al día durante un año. ¿Contratar?';
    if (!await _confirmar(lugar.titulo, texto, 'Contratar')) return;
    await _pagar('f${lugar.favoritoId}', () => _service.contratar(lugar.favoritoId));
  }

  Future<void> _renovar(Estudio e) async {
    final precio = _datos?.precioEstudio ?? 0;
    final pago = precio > 0 ? ' por $precio ✨' : '';
    final texto = e.activo
        ? 'Renovar suma un año más de capturas$pago. ¿Renovar?'
        : 'Renovar reanuda las capturas por un año más${precio > 0 ? ',$pago' : ''}. ¿Renovar?';
    if (!await _confirmar(e.titulo, texto, 'Renovar')) return;
    await _pagar('e${e.id}', () => _service.renovar(e.id));
  }

  // El saldo lo deja el servicio en [coinBalance]; aquí solo se recarga.
  Future<void> _pagar(String clave, Future<Estudio> Function() pago) async {
    setState(() => _ocupado = clave);
    try {
      final e = await pago();
      if (!mounted) return;
      setState(() {
        final d = _datos!;
        _datos = Observatorio(
          precioEstudio: d.precioEstudio,
          precioDescarga: d.precioDescarga,
          lugares: [
            for (final l in d.lugares) l.estudio?.id == e.id || 'f${l.favoritoId}' == clave ? l.conEstudio(e) : l,
          ],
          huerfanos: d.huerfanos,
        );
      });
      _avisar('Estudio del cielo activo hasta el ${_fecha(e.expira)}.');
    } on ApiException catch (e) {
      // 422: falta polvo, ya tiene estudio o aún no se puede renovar.
      if (mounted) _avisar(e.message, error: true);
    } finally {
      if (mounted) setState(() => _ocupado = null);
    }
  }

  void _avisar(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: error ? Colors.redAccent : Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kFondo,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Text('🔭', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('Cielos', style: TextStyle(color: kCian, fontWeight: FontWeight.bold, fontSize: 24)),
          ],
        ),
        actions: [
          ValueListenableBuilder<int?>(
            valueListenable: coinBalance,
            builder: (context, coins, _) => coins == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Text(
                        '$coins ✨',
                        semanticsLabel: '$coins de Polvo Estelar',
                        style: const TextStyle(color: kCian, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: kCian,
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            const Text(
              'El cielo de ahora en tus lugares favoritos. Con un Estudio del cielo, guardamos su '
              'clima y sus astros cuatro veces al día durante un año.',
              style: TextStyle(color: kTexto, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ..._contenido(),
          ],
        ),
      ),
    );
  }

  List<Widget> _contenido() {
    final d = _datos;
    if (d == null) {
      return [
        if (_error != null)
          _Mensaje(
            icono: Icons.cloud_off_rounded,
            texto: _error!,
            accion: TextButton(
              onPressed: _cargar,
              child: const Text('Reintentar', style: TextStyle(color: kCian)),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: CircularProgressIndicator(color: kCian)),
          ),
      ];
    }
    return [
      if (d.lugares.isEmpty)
        const _Mensaje(
          icono: Icons.travel_explore,
          texto: 'Aún no tienes lugares favoritos. Guarda un lugar desde el mapa y su cielo '
              'aparecerá aquí, listo para mirarlo y estudiarlo.',
        ),
      for (final l in d.lugares) _tarjeta(l, d),
      for (final e in d.huerfanos) _huerfano(e, d),
    ];
  }

  Widget _tarjeta(LugarCielo l, Observatorio d) {
    final c = l.clima;
    String n(double? v, String unidad, {int dec = 0}) =>
        v == null ? '—' : '${v.toStringAsFixed(dec)}$unidad';

    return _Tarjeta(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(l.titulo,
                  style: const TextStyle(color: kTexto, fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            if (c?.reserva == true) const _Distintivo('clima de reserva', kAmbar),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(iconoWmo(c?.codigoWmo, deDia: c?.esDeDia ?? true), color: kCian, size: 40),
            const SizedBox(width: 14),
            Text(
              c?.temperatura == null ? '—°' : '${c!.temperatura!.round()}°',
              style: const TextStyle(color: kTexto, fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _Dato(Icons.air, n(c?.vientoKmh, ' km/h')),
                  _Dato(Icons.water_drop_outlined, n(c?.humedadPct, ' %')),
                  _Dato(Icons.umbrella_outlined, n(c?.precipitacionMm, ' mm', dec: 1)),
                ],
              ),
            ),
          ],
        ),
        const Divider(color: Colors.white10, height: 24),
        _pie(l, d),
      ],
    );
  }

  Widget _pie(LugarCielo l, Observatorio d) {
    final e = l.estudio;
    if (e == null) {
      final ocupado = _ocupado == 'f${l.favoritoId}';
      return _Boton(
        texto: _conPrecio('Estudiar este cielo', d.precioEstudio, sufijo: '/año'),
        icono: Icons.science_outlined,
        ocupado: ocupado,
        onTap: _ocupado == null ? () => _contratar(l) : null,
      );
    }
    return _pieEstudio(e, d);
  }

  Widget _pieEstudio(Estudio e, Observatorio d, {bool huerfano = false}) {
    final ocupado = _ocupado == 'e${e.id}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          e.activo
              ? (huerfano ? 'El estudio sigue capturando hasta el ${_fecha(e.expira)}' : 'Estudio activo · vence ${_fecha(e.expira)}')
              : 'Estudio en pausa · lo capturado queda',
          style: TextStyle(color: e.activo ? kTexto : kAmbar, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Boton(
              texto: e.activo && !huerfano ? 'Ver estudio' : 'Ver lo capturado',
              icono: Icons.insights,
              onTap: widget.onVerEstudio == null ? null : () => widget.onVerEstudio!(e, d),
            ),
            if (e.renovable && !huerfano)
              _Boton(
                texto: _conPrecio('Renovar', d.precioEstudio),
                icono: Icons.autorenew,
                ocupado: ocupado,
                onTap: _ocupado == null ? () => _renovar(e) : null,
              ),
          ],
        ),
      ],
    );
  }

  Widget _huerfano(Estudio e, Observatorio d) {
    return _Tarjeta(
      children: [
        Text(e.titulo, style: const TextStyle(color: kTexto, fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('El lugar ya no está en tus favoritos',
            style: TextStyle(color: kTextoTenue, fontSize: 13)),
        const Divider(color: Colors.white10, height: 24),
        _pieEstudio(e, d, huerfano: true),
      ],
    );
  }
}

String _fecha(DateTime? f) {
  if (f == null) return '—';
  final l = f.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kTarjeta,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.icono, this.texto);

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: kTextoTenue),
          const SizedBox(width: 4),
          Text(texto, style: const TextStyle(color: kTexto, fontSize: 13)),
        ],
      );
}

class _Distintivo extends StatelessWidget {
  const _Distintivo(this.texto, this.color);

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(texto, style: TextStyle(color: color, fontSize: 12)),
      );
}

class _Boton extends StatelessWidget {
  const _Boton({required this.texto, required this.icono, this.onTap, this.ocupado = false});

  final String texto;
  final IconData icono;
  final VoidCallback? onTap;
  final bool ocupado;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: kCian,
        side: BorderSide(color: kCian.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: ocupado
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: kCian))
          : Icon(icono, size: 18),
      label: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.icono, required this.texto, this.accion});

  final IconData icono;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(icono, color: kTextoTenue, size: 40),
          const SizedBox(height: 12),
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: kTextoTenue, fontSize: 14)),
          ?accion,
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/observatorio.dart';
import '../services/astral_chart_service.dart';
import '../services/observatorio_service.dart';
import '../widgets/firmamento/tablas.dart';
import 'astral_charts_screen.dart';
import 'cielos_screen.dart';

/// El Observatorio: Cielos (el clima de los favoritos) y Firmamentos (las
/// cartas astrales), con un conmutador visible para ir y volver.
class ObservatorioTab extends StatefulWidget {
  const ObservatorioTab({super.key, this.observatorio, this.cartas, this.onVerEstudio});

  final ObservatorioService? observatorio;
  final AstralChartService? cartas;
  final void Function(BuildContext context, Estudio estudio, Observatorio datos)? onVerEstudio;

  @override
  State<ObservatorioTab> createState() => _ObservatorioTabState();
}

class _ObservatorioTabState extends State<ObservatorioTab> {
  bool _firmamentos = false;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kFondo,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  _Lado(texto: '🔭 Cielos', activo: !_firmamentos, onTap: () => setState(() => _firmamentos = false)),
                  _Lado(texto: '🌟 Firmamentos', activo: _firmamentos, onTap: () => setState(() => _firmamentos = true)),
                ],
              ),
            ),
          ),
          // Las dos caras quedan vivas: volver no recarga.
          Expanded(
            child: IndexedStack(
              index: _firmamentos ? 1 : 0,
              children: [
                CielosScreen(
                  service: widget.observatorio,
                  onVerEstudio: widget.onVerEstudio == null
                      ? null
                      : (e, d) => widget.onVerEstudio!(context, e, d),
                ),
                AstralChartsScreen(service: widget.cartas),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Lado extends StatelessWidget {
  const _Lado({required this.texto, required this.activo, required this.onTap});

  final String texto;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: activo ? kCian.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              texto,
              style: TextStyle(
                color: activo ? kCian : kTextoTenue,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

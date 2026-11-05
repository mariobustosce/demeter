import 'dart:math';

import 'package:flutter/material.dart';

import '../../theme/consultas_theme.dart';

/// El fondo de la consola (`.cns-root`): degradado a 160°, dos halos y 26
/// estrellas de 2 px que titilan. Con «quitar animaciones» quedan quietas.
class FondoConsultas extends StatefulWidget {
  const FondoConsultas({super.key, required this.child, this.semilla});

  final Widget child;

  /// Para los tests: posiciones de estrellas fijas.
  final int? semilla;

  @override
  State<FondoConsultas> createState() => _FondoConsultasState();
}

class _FondoConsultasState extends State<FondoConsultas> with SingleTickerProviderStateMixin {
  static const _cuantas = 26;

  late final AnimationController _titileo = AnimationController(vsync: this, duration: CnsDuraciones.titileo);
  late final List<_Estrella> _estrellas;

  @override
  void initState() {
    super.initState();
    final azar = Random(widget.semilla);
    _estrellas = List.generate(
      _cuantas,
      (_) => _Estrella(azar.nextDouble(), azar.nextDouble(), azar.nextDouble()),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _titileo
        ..stop()
        ..value = .3;
    } else if (!_titileo.isAnimating) {
      _titileo.repeat();
    }
  }

  @override
  void dispose() {
    _titileo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          // 160° en CSS: de arriba-izquierda hacia abajo, apenas inclinado.
          begin: Alignment(-0.34, -1),
          end: Alignment(0.34, 1),
          colors: [CnsColores.fondoA, CnsColores.fondoB, CnsColores.fondoC],
          stops: [0, .42, 1],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.76, -1.1),
                    radius: 1.1,
                    colors: [CnsColores.haloCian, CnsColores.transparente],
                    stops: [0, .62],
                  ),
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.84, -0.95),
                    radius: .95,
                    colors: [CnsColores.haloVioleta, CnsColores.transparente],
                    stops: [0, .6],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: _Cielo(_estrellas, _titileo)),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Estrella {
  const _Estrella(this.x, this.y, this.desfase);

  final double x;
  final double y;
  final double desfase;
}

class _Cielo extends CustomPainter {
  _Cielo(this.estrellas, this.t) : super(repaint: t);

  final List<_Estrella> estrellas;
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    // Solo la primera pantalla: las estrellas viven arriba, como en la web.
    final alto = min(size.height, 900.0);
    for (final e in estrellas) {
      // .12 ↔ .7 en 5 s, cada una con su desfase.
      final fase = (t.value + e.desfase) % 1;
      final opacidad = .12 + .58 * (.5 - .5 * cos(fase * 2 * pi));
      canvas.drawCircle(
        Offset(e.x * size.width, e.y * alto),
        1,
        Paint()..color = CnsColores.estrella.withValues(alpha: opacidad),
      );
    }
  }

  @override
  bool shouldRepaint(_Cielo old) => old.estrellas != estrellas;
}

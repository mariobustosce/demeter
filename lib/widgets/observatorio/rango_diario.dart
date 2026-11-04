import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/estudio_detalle.dart';
import '../firmamento/tablas.dart';

// Tonos ya usados en la app (dignidades, signos y elementos).
const kTonoCalido = Color(0xFFFF5D5D);
const kTonoFresco = Color(0xFF74C0FC);
const kTonoNormal = Color(0xFFFF9A3C);
const kColorLluvia = Color(0xFF5AA6D8);

/// Cálido, fresco o normal según la anomalía (±1 °C), como la web.
Color tonoAnomalia(double? a) => a == null || a.abs() < 1 ? kTonoNormal : (a > 0 ? kTonoCalido : kTonoFresco);

/// `+2,3` / `−1,4`.
String anomaliaConSigno(double a) =>
    '${a >= 0 ? '+' : '−'}${a.abs().toStringAsFixed(1).replaceAll('.', ',')}';

/// Rango diario contra la normal: una barra de tmin a tmax por día, la banda
/// de la normal detrás y, abajo, la lluvia de cada día en barras finas.
class RangoDiario extends StatelessWidget {
  const RangoDiario({super.key, required this.dias});

  final List<DiaEstudio> dias;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Temperatura: rango de cada día contra la normal',
      child: SizedBox(
        height: 260,
        width: double.infinity,
        child: CustomPaint(painter: RangoDiarioPainter(dias)),
      ),
    );
  }
}

class RangoDiarioPainter extends CustomPainter {
  RangoDiarioPainter(this.dias);

  final List<DiaEstudio> dias;

  static const double _izq = 30;
  static const double _arriba = 14;
  static const double _altoTemp = 170;
  static const double _yEtiquetas = _arriba + _altoTemp + 12;
  static const double _yLluvia = _yEtiquetas + 14;
  static const double _altoLluvia = 40;

  void _texto(Canvas c, String t, Offset centro, Color color, double fs, {bool derecha = false}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(color: color, fontSize: fs, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(derecha ? centro.dx - tp.width : centro.dx - tp.width / 2, centro.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (dias.isEmpty) return;

    // Escala: todos los extremos y las normales, ±1 °C.
    final valores = <double>[
      for (final d in dias) ...[?d.tmax, ?d.tmin, if (d.normal case final n?) ...[n.$1, n.$2]],
    ];
    if (valores.isEmpty) return;
    final lo = valores.reduce(math.min) - 1;
    final hi = valores.reduce(math.max) + 1;
    double y(double t) => _arriba + (hi - t) / (hi - lo) * _altoTemp;

    final ancho = (size.width - _izq) / dias.length;
    double x(int i) => _izq + ancho * (i + 0.5);

    // Guías y eje.
    final guia = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (final t in [hi - 1, (hi + lo) / 2, lo + 1]) {
      canvas.drawLine(Offset(_izq, y(t)), Offset(size.width, y(t)), guia);
      _texto(canvas, '${t.round()}°', Offset(_izq - 4, y(t)), kTextoTenue, 10, derecha: true);
    }

    // Banda de la normal: necesita al menos dos días con normal.
    final conNormal = [for (var i = 0; i < dias.length; i++) if (dias[i].normal != null) i];
    if (conNormal.length >= 2) {
      final banda = Path()..moveTo(x(conNormal.first), y(dias[conNormal.first].normal!.$1));
      for (final i in conNormal.skip(1)) {
        banda.lineTo(x(i), y(dias[i].normal!.$1));
      }
      for (final i in conNormal.reversed) {
        banda.lineTo(x(i), y(dias[i].normal!.$2));
      }
      banda.close();
      canvas.drawPath(banda, Paint()..color = kTextoTenue.withValues(alpha: 0.2));
    }

    final maxLluvia = dias.map((d) => d.lluvia ?? 0).fold<double>(0, math.max);

    for (var i = 0; i < dias.length; i++) {
      final d = dias[i];
      final cx = x(i);

      if (d.conDatos) {
        final tono = tonoAnomalia(d.anomalia);
        final top = y(d.tmax!);
        final alto = math.max(2.0, y(d.tmin!) - top);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(cx - ancho * 0.23, top, ancho * 0.46, alto), const Radius.circular(3)),
          Paint()..color = tono,
        );
        if (d.anomalia != null && d.anomalia!.abs() >= 1) {
          _texto(canvas, anomaliaConSigno(d.anomalia!), Offset(cx, top - 7), tono, 9);
        }
      } else {
        // Día sin datos: un hueco visible, sin interpolar.
        final hueco = Paint()
          ..color = kTextoTenue.withValues(alpha: 0.25)
          ..strokeWidth = 1;
        for (var py = _arriba; py < _arriba + _altoTemp; py += 6) {
          canvas.drawLine(Offset(cx, py), Offset(cx, py + 2), hueco);
        }
      }

      // Día del mes.
      final dia = d.fecha.length >= 10 ? d.fecha.substring(8, 10) : d.fecha;
      if (dias.length <= 16 || i.isEven) {
        _texto(canvas, dia, Offset(cx, _yEtiquetas), kTextoTenue, 9.5);
      }

      // Lluvia diaria en barras finas.
      final ll = d.lluvia;
      if (ll != null && ll > 0 && maxLluvia > 0) {
        final h = math.max(2.0, ll / maxLluvia * _altoLluvia);
        canvas.drawRect(
          Rect.fromLTWH(cx - 2, _yLluvia + _altoLluvia - h, 4, h),
          Paint()..color = kColorLluvia.withValues(alpha: d.lluviaAprox ? 0.5 : 0.9),
        );
      }
    }
    canvas.drawLine(
      const Offset(_izq, _yLluvia + _altoLluvia),
      Offset(size.width, _yLluvia + _altoLluvia),
      guia,
    );
    _texto(canvas, 'mm', const Offset(_izq - 4, _yLluvia + _altoLluvia / 2), kTextoTenue, 10, derecha: true);
  }

  @override
  bool shouldRepaint(RangoDiarioPainter old) => old.dias != dias;
}

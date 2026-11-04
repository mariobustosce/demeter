import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/firmamento.dart';
import 'anticolision.dart';
import 'tablas.dart';

// Radios en unidades de la rueda web (viewBox de 224, centro en 112).
const double _rOut = 94;
const double _rGlifoSigno = 87;
const double _rSign = 80;
const double _rTick = 77;
const double _rCuerpo = 69;
const double _rGuia = 76;
const double _rCasa = 45.5;
const double _rHub = 41;
const double _rRotuloEje = 103;
const double _rDisco = 6.6;

double _mod360(double x) => ((x % 360) + 360) % 360;

/// Posiciones de la rueda para un tamaño: las usa el pintor y el toque.
class RuedaLayout {
  RuedaLayout(this.f, this.lado)
      : s = lado / 224,
        centro = Offset(lado / 2, lado / 2) {
    real = [for (final c in f.cuerpos) ang(c.longitud)];
    pos = separarGlifos(real);
  }

  final Firmamento f;
  final double lado;

  /// Escala de una unidad de la rueda web a píxeles.
  final double s;
  final Offset centro;

  /// Ángulo real de cada cuerpo, en el orden de `f.cuerpos`.
  late final List<double> real;

  /// Ángulo del glifo, ya separado de sus vecinos.
  late final List<double> pos;

  /// El Ascendente a la izquierda; el zodiaco corre antihorario.
  double ang(double longitud) => _mod360(180 - (longitud - f.asc));

  Offset xy(double angulo, double r) {
    final rad = angulo * math.pi / 180;
    return centro + Offset(math.cos(rad), math.sin(rad)) * (r * s);
  }

  /// El cuerpo cuyo glifo está bajo [p], o `null`.
  String? cuerpoEn(Offset p) {
    final alcance = math.max(_rDisco * s * 1.8, 18.0);
    String? mejor;
    var dist = double.infinity;
    for (var i = 0; i < f.cuerpos.length; i++) {
      final d = (xy(pos[i], _rCuerpo) - p).distance;
      if (d < alcance && d < dist) {
        dist = d;
        mejor = f.cuerpos[i].clave;
      }
    }
    return mejor;
  }
}

/// Rueda natal: anillo zodiacal, casas, ejes, cuerpos y aspectos.
///
/// Tocar un planeta llama a [onTocar] con su clave (o `null` fuera de los
/// glifos). Con [cuerpo] se resaltan sus aspectos; con [par], ese aspecto.
class RuedaNatal extends StatelessWidget {
  const RuedaNatal({
    super.key,
    required this.firmamento,
    this.cuerpo,
    this.par,
    this.onTocar,
  });

  final Firmamento firmamento;
  final String? cuerpo;
  final (String, String)? par;
  final ValueChanged<String?>? onTocar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final lado = math.min(c.maxWidth.isFinite ? c.maxWidth : 360.0, 560.0);
      final layout = RuedaLayout(firmamento, lado);
      return Center(
        child: Semantics(
          label: 'Rueda natal',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: onTocar == null ? null : (d) => onTocar!(layout.cuerpoEn(d.localPosition)),
            child: CustomPaint(
              size: Size.square(lado),
              painter: RuedaPainter(layout, cuerpo: cuerpo, par: par),
            ),
          ),
        ),
      );
    });
  }
}

class RuedaPainter extends CustomPainter {
  RuedaPainter(this.l, {this.cuerpo, this.par});

  final RuedaLayout l;
  final String? cuerpo;
  final (String, String)? par;

  Firmamento get f => l.f;
  double get s => l.s;

  bool get _enfoque => cuerpo != null || par != null;

  bool _aspectoEncendido(Aspecto a) {
    if (par != null) return a.une(par!.$1, par!.$2);
    if (cuerpo != null) return a.toca(cuerpo!);
    return false;
  }

  bool _cuerpoEncendido(String clave) {
    if (par != null) return clave == par!.$1 || clave == par!.$2;
    if (cuerpo == null) return true;
    if (clave == cuerpo) return true;
    return f.aspectos.any((a) => a.toca(cuerpo!) && a.toca(clave));
  }

  // Tamaños de letra con un mínimo legible en un teléfono.
  double _fs(double base, double minimo) => math.max(base * s, minimo);

  void _texto(Canvas canvas, String texto, Offset centro, Color color, double fontSize,
      {FontWeight peso = FontWeight.normal}) {
    final tp = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: peso, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centro - Offset(tp.width / 2, tp.height / 2));
  }

  void _linea(Canvas canvas, Offset a, Offset b, Paint p, {List<double>? guiones}) {
    if (guiones == null) {
      canvas.drawLine(a, b, p);
      return;
    }
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var t = 0.0;
    var i = 0;
    while (t < total) {
      final largo = guiones[i % guiones.length];
      if (i.isEven) canvas.drawLine(a + dir * t, a + dir * math.min(t + largo, total), p);
      t += largo;
      i++;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = l.centro;
    Rect circulo(double r) => Rect.fromCircle(center: c, radius: r * s);
    double rad(double g) => g * math.pi / 180;

    // Fondo y borde, con la paleta de la app.
    canvas.drawCircle(c, _rOut * s, Paint()..color = kFondo);
    canvas.drawCircle(
      c,
      _rOut * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = kVioleta.withValues(alpha: 0.25),
    );

    // Anillo zodiacal: sectores del color de su elemento.
    for (var i = 0; i < 12; i++) {
      final a1 = l.ang(i * 30.0);
      final sig = kSignos[i];
      final colorElemento = kElementos[sig.elemento] ?? kTextoTenue;
      final path = Path()
        ..moveTo(l.xy(a1, _rSign).dx, l.xy(a1, _rSign).dy)
        ..lineTo(l.xy(a1, _rOut).dx, l.xy(a1, _rOut).dy)
        ..arcTo(circulo(_rOut), rad(a1), rad(-30), false)
        ..lineTo(l.xy(a1 - 30, _rSign).dx, l.xy(a1 - 30, _rSign).dy)
        ..arcTo(circulo(_rSign), rad(a1 - 30), rad(30), false)
        ..close();
      canvas.drawPath(path, Paint()..color = colorElemento.withValues(alpha: 0.13));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.4 * s
          ..color = Colors.black.withValues(alpha: 0.35),
      );
      _texto(canvas, glifoTexto(sig.glifo), l.xy(l.ang(i * 30.0 + 15), _rGlifoSigno), colorElemento,
          _fs(10, 9));
    }
    canvas.drawCircle(
      c,
      _rSign * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5 * s
        ..color = kTextoTenue.withValues(alpha: 0.3),
    );

    // Cúspides intermedias (los ejes van aparte) y número de casa al medio.
    final cusp = f.cuspides;
    if (cusp.length == 12) {
      final fina = Paint()
        ..strokeWidth = 0.5 * s
        ..color = kTextoTenue.withValues(alpha: 0.22);
      for (var i = 0; i < 12; i++) {
        if (i % 3 != 0) {
          canvas.drawLine(l.xy(l.ang(cusp[i]), _rHub), l.xy(l.ang(cusp[i]), _rSign), fina);
        }
        final arco = _mod360(cusp[(i + 1) % 12] - cusp[i]);
        _texto(canvas, '${i + 1}', l.xy(l.ang(cusp[i] + arco / 2), _rCasa),
            kTextoTenue.withValues(alpha: 0.55), _fs(4.6, 7));
      }
    }

    // Ejes AC–DC y MC–IC, más gruesos, con su rótulo fuera del anillo.
    for (final (clave, opuesto) in const [('asc', 'dsc'), ('mc', 'ic')]) {
      final eje = f.ejes[clave];
      if (eje == null) continue;
      for (final (k, principal) in [(clave, true), (opuesto, false)]) {
        final lon = principal ? eje.longitud : eje.longitud + 180;
        final a = l.ang(lon);
        final info = kEjes[k]!;
        canvas.drawLine(
          l.xy(a, _rHub),
          l.xy(a, _rOut),
          Paint()
            ..strokeWidth = (principal ? 1.6 : 1) * s
            ..color = info.color.withValues(alpha: principal ? 0.9 : 0.55),
        );
        _texto(canvas, info.sigla, l.xy(a, _rRotuloEje), info.color.withValues(alpha: principal ? 1 : 0.6),
            _fs(7, 9), peso: FontWeight.bold);
      }
    }

    canvas.drawCircle(c, _rHub * s, Paint()..color = Colors.black.withValues(alpha: 0.4));

    // Aspectos entre los grados reales, no entre los glifos desplazados.
    for (final a in f.aspectos) {
      final la = f.longitud(a.a), lb = f.longitud(a.b);
      if (la == null || lb == null) continue;
      final on = _aspectoEncendido(a);
      var opacidad = a.menor ? 0.3 : 0.4 + 0.45 * a.exactitud;
      if (_enfoque) opacidad = on ? 1 : 0.05;
      final p = Paint()
        ..strokeWidth = (a.menor ? 0.45 : 0.4 + 1.1 * a.exactitud) * s * (on ? 1.4 : 1)
        ..color = a.color.withValues(alpha: opacidad);
      _linea(canvas, l.xy(l.ang(la), _rHub), l.xy(l.ang(lb), _rHub), p,
          guiones: a.menor ? [1.4 * s, 1.6 * s] : null);
    }

    // Cuerpos: línea guía al grado real, disco con el glifo y su etiqueta.
    for (var i = 0; i < f.cuerpos.length; i++) {
      final cu = f.cuerpos[i];
      final real = l.real[i], pos = l.pos[i];
      final alfa = _enfoque && !_cuerpoEncendido(cu.clave) ? 0.35 : 1.0;

      final guia = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5 * s
        ..color = cu.color.withValues(alpha: 0.5 * alfa);
      canvas.drawPath(
        Path()
          ..moveTo(l.xy(real, _rSign).dx, l.xy(real, _rSign).dy)
          ..lineTo(l.xy(real, _rTick).dx, l.xy(real, _rTick).dy)
          ..lineTo(l.xy(pos, _rGuia).dx, l.xy(pos, _rGuia).dy),
        guia,
      );

      final centro = l.xy(pos, _rCuerpo);
      final radio = math.max(_rDisco * s, 9.0);
      canvas.drawCircle(centro, radio, Paint()..color = const Color(0xFF060612).withValues(alpha: 0.92 * alfa));
      canvas.drawCircle(
        centro,
        radio,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9 * math.max(s, 1)
          ..color = cu.color.withValues(alpha: alfa),
      );
      _texto(canvas, glifoTexto(cu.simbolo), centro, cu.color.withValues(alpha: alfa), _fs(8, 11));

      // En columna hacia el centro: grado, signo y minutos (con R).
      final g = cu.gradoEnSigno;
      final grado = g.floor();
      final minutos = ((g - grado) * 60).floor().clamp(0, 59);
      final sig = signoDe(cu.signo);
      _texto(canvas, '$grado°', l.xy(pos, _rCuerpo - 10), kColorE.withValues(alpha: alfa), _fs(4.4, 7));
      _texto(canvas, glifoTexto(sig.glifo), l.xy(pos, _rCuerpo - 15),
          sig.color.withValues(alpha: 0.85 * alfa), _fs(4.6, 7));
      _texto(
        canvas,
        '${minutos.toString().padLeft(2, '0')}′${cu.retrogrado ? ' R' : ''}',
        l.xy(pos, _rCuerpo - 20),
        (cu.retrogrado ? kColorR : const Color(0xFF7C8EA1)).withValues(alpha: alfa),
        _fs(4, 6.5),
      );
    }
  }

  @override
  bool shouldRepaint(RuedaPainter old) =>
      old.l.f != l.f || old.l.lado != l.lado || old.cuerpo != cuerpo || old.par != par;
}

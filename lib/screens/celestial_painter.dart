import 'dart:math';
import 'package:flutter/material.dart';

class CelestialPainter extends CustomPainter {
  final Map<String, dynamic> data;
  final double animationValue;
  
  // Cache de colores procesados para evitar RegExp en paint
  late final List<Color> _skyColors;

  CelestialPainter({
    required this.data,
    required this.animationValue,
  }) {
    _skyColors = _extractSkyColors();
  }

  List<Color> _extractSkyColors() {
    final skyColorsData = data['sky_colors'];
    List<Color> extracted = [];

    try {
      if (skyColorsData is String && skyColorsData.contains(',') && !skyColorsData.contains('gradient')) {
        extracted = skyColorsData.split(',').map((c) => _hexToColor(c.trim())).toList();
      } else if (skyColorsData is Map && skyColorsData['colors'] is List) {
        extracted = (skyColorsData['colors'] as List).map((c) => _hexToColor(c.toString())).toList();
      } else if (skyColorsData is Map && skyColorsData['gradient'] is String) {
        final gradientStr = skyColorsData['gradient'] as String;
        final hexPattern = RegExp(r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b');
        final matches = hexPattern.allMatches(gradientStr);
        if (matches.isNotEmpty) {
          extracted = matches.map((m) => _hexToColor(m.group(0)!)).toList();
        }
      }
    } catch (_) {}

    // Fallback garantizado: Siempre al menos 2 colores para el gradiente
    if (extracted.length < 2) {
      final skyType = (skyColorsData is Map) ? skyColorsData['type']?.toString() : null;
      if (skyType == 'day') {
        return [const Color(0xFFdbeafe), const Color(0xFF1e40af)];
      } else {
        return [const Color(0xFF0F172A), const Color(0xFF312E81)];
      }
    }
    return extracted;
  }

  // Helper robusto para hex
  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 3) {
      hex = hex.split('').map((c) => c + c).join();
    }
    if (hex.length == 6) {
      hex = 'ff$hex';
    }
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return Colors.black;
    }
  }

  // Helper para curvar Bézier Cuadrada
  Offset _getBezierPos(double t, Offset p0, Offset p1, Offset p2) {
    double x = pow(1 - t, 2) * p0.dx + 2 * (1 - t) * t * p1.dx + pow(t, 2) * p2.dx;
    double y = pow(1 - t, 2) * p0.dy + 2 * (1 - t) * t * p1.dy + pow(t, 2) * p2.dy;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. SEGURIDAD: Si no hay tamaño, no dibujamos.
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;

    // 2. FALLBACK DE DATOS: Si no hay datos, dibujamos el fondo para evitar pantalla negra.
    if (data.isEmpty) {
      final nightGradient = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F172A), Color(0xFF312E81)],
        ).createShader(rect);
      canvas.drawRect(rect, nightGradient);
      return;
    }


    // 3. FONDO PRINCIPAL (solo una vez)
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _skyColors.isNotEmpty ? _skyColors : [const Color(0xFF0F172A), const Color(0xFF312E81)],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Coordinadas de diseño base
    const double baseWidth = 1080;
    const double baseHeight = 2424;
    final double scaleX = size.width / baseWidth;
    final double scaleY = size.height / baseHeight;

    // --- 2. ESTRELLAS ---
    final skyColorsData = data['sky_colors'];
    final visibility = (skyColorsData is Map ? skyColorsData['star_visibility'] : data['star_visibility'] ?? 'high').toString();
    if (visibility != 'none') {
      final int starCount = visibility == 'high' ? 30 : 10; // Reducido para estabilidad
      final random = Random(42);
      final starPaint = Paint()..color = Colors.white;
      for (int i = 0; i < starCount; i++) {
        double x = random.nextDouble() * 1060 + 20;
        double y = random.nextDouble() * 2000 + 20;
        double r = random.nextDouble() * 2 + 1;
        
        double baseOpacity = visibility == 'high' ? 0.6 : 0.3;
        double twinkle = 0.2 * sin(animationValue * 2 * pi + random.nextDouble() * 2 * pi);
        
        canvas.drawCircle(
          Offset(x * scaleX, y * scaleY),
          r * scaleX,
          starPaint..color = Colors.white.withOpacity((baseOpacity + twinkle).clamp(0.1, 1.0)),
        );
      }
    }

    // --- ARCOS DEFINIDOS (P0: Izquierda, P1: Centro/Curva, P2: Derecha) ---
    final arcoCasasP0 = Offset(100 * scaleX, 500 * scaleY);
    final arcoCasasP1 = Offset(540 * scaleX, 250 * scaleY);
    final arcoCasasP2 = Offset(980 * scaleX, 500 * scaleY);

    final arcoZodiacalP0 = Offset(80 * scaleX, 850 * scaleY);
    final arcoZodiacalP1 = Offset(540 * scaleX, 550 * scaleY);
    final arcoZodiacalP2 = Offset(1000 * scaleX, 850 * scaleY);

    final arcoAstroP0 = Offset(50 * scaleX, 2100 * scaleY);
    final arcoAstroP1 = Offset(540 * scaleX, 1750 * scaleY);
    final arcoAstroP2 = Offset(1030 * scaleX, 2100 * scaleY);

    // Función auxiliar dibujarPath
    void drawArcPath(Offset p0, Offset p1, Offset p2, Paint paint) {
      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy);
      canvas.drawPath(path, paint);
    }

    // Dibuja la línea del Zodiaco
    drawArcPath(
      arcoZodiacalP0, arcoZodiacalP1, arcoZodiacalP2, 
      Paint()
        ..color = const Color(0xFF475569).withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * scaleX
    );

    // Dibuja la línea Astronómica con dashes
    // Flutter no tiene dash nativo en canvas sin un PathMetric, 
    // pero podemos dejarlo solido elegante
    drawArcPath(
      arcoAstroP0, arcoAstroP1, arcoAstroP2, 
      Paint()
        ..color = const Color(0xFF334155).withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * scaleX
    );

    // --- 3. CASAS ANGULARES ---
    final casas = (data['casas'] is Map) ? (data['casas']['angulares'] ?? {}) : {};
    final dominantHouse = (data['casas'] is Map) ? data['casas']['dominant_house']?.toString() : null;
    
    // Función auxiliar para texto
    void drawText(String text, Offset pos, double fontSize, Color color, {FontWeight weight = FontWeight.bold, double opacity = 1.0}) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: color.withOpacity(opacity), fontSize: fontSize * scaleX, fontWeight: weight),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();
      textPainter.paint(canvas, pos - Offset(textPainter.width / 2, textPainter.height / 2));
    }

    if (casas is Map) {
      casas.forEach((key, casa) {
        if (casa is! Map) return;
        double progreso = (casa['progress'] ?? 0.0).toDouble();
        Offset pos = _getBezierPos(progreso, arcoCasasP0, arcoCasasP1, arcoCasasP2);
        pos = Offset(pos.dx, pos.dy - 150 * scaleY); // offsetVertical = -150 en SVG

        Color color = _hexToColor(casa['color'] ?? '#e74c3c');
        bool isDominant = (key.toString() == dominantHouse);
        double radius = (isDominant ? 18 : 15) * scaleX;

        // Glow effect oscilante
        if (isDominant) {
          double glowRadius = radius + (6 * (1 + 0.2 * sin(animationValue * 4 * pi)));
          canvas.drawCircle(pos - Offset(0, 20 * scaleY), glowRadius, Paint()..color = color.withOpacity(0.3));
        }

        // Circulo base
        canvas.drawCircle(pos - Offset(0, 20 * scaleY), radius, Paint()..color = color);

        // Simbolo
        drawText(casa['simbolo'] ?? '', pos - Offset(0, 16 * scaleY), isDominant ? 16 : 14, Colors.white);
        
        // Titulo
        drawText("${casa['titulo']}${isDominant ? ' 👑' : ''}", pos + Offset(0, 15 * scaleY), 11, color);
      });
    }

    // --- 4. ZODIACO ---
    final zodiacoData = data['zodiaco'] as Map?;
    final constelaciones = zodiacoData != null ? (zodiacoData['filtrados'] ?? zodiacoData['potentes'] ?? {}) : {};
    if (constelaciones is Map) {
      constelaciones.forEach((key, cn) {
        if (cn is! Map) return;
        double progreso = (cn['progress'] ?? 0.0).toDouble();
        Offset pos = _getBezierPos(progreso, arcoZodiacalP0, arcoZodiacalP1, arcoZodiacalP2);
        pos = Offset(pos.dx, pos.dy - 200 * scaleY); // offsetZodiacal = -200
        
        Color color = _hexToColor(cn['color'] ?? '#ffffff');
        double radius = 15 * scaleX; // Basado en ranking logica
        
        // Circulo base
        canvas.drawCircle(pos - Offset(0, 20 * scaleY), radius, Paint()..color = color);

        // Simbolo
        drawText(cn['simbolo'] ?? '', pos - Offset(0, 16 * scaleY), 16, Colors.white);
        
        // Titulo
        drawText(cn['nombre'] ?? '', pos + Offset(0, 15 * scaleY), 10, color);
      });
    }

    // --- 5. PLANETAS VISIBLES ---
    final planetasData = data['planetas'] as Map?;
    final planetas = planetasData != null ? (planetasData['visibles'] ?? {}) : {};
    if (planetas is Map) {
      final pPaint = Paint()..style = PaintingStyle.fill;
      planetas.forEach((key, planetData) {
        if (planetData is! Map) return;

        // FILTRO: Evitar dibujar 'sol' o 'sun' en este arco de planetas
        final String planetKey = key.toString().toLowerCase();
        if (planetKey == 'sol' || planetKey == 'sun') return;

        double alt = (planetData['altitude'] ?? (planetData['posicion_actual'] is Map ? planetData['posicion_actual']['altitude'] : -1.0)).toDouble();
        if (alt > 0) {
          double azimut = (planetData['azimuth'] ?? (planetData['posicion_actual'] is Map ? planetData['posicion_actual']['azimuth'] : 0.0)).toDouble();
          
          double porcentajeX = (360 - azimut) / 360;
          double xBase = ((porcentajeX * baseWidth) + (baseWidth / 2)) % baseWidth;
          
          const Map<String, int> orden = {
            'mercurio': 0, 'venus': 1, 'marte': 2, 'jupiter': 3, 
            'saturno': 4, 'urano': 5, 'neptuno': 6, 'pluton': 7
          };
          int nivel = orden[key.toString().toLowerCase()] ?? 0;
          double yHorizonte = 1650;
          double yCenit = 350;
          double separacion = (yHorizonte - yCenit) / 9;
          double yBase = yHorizonte - (separacion * (nivel + 1));

          Offset pos = Offset(xBase * scaleX, yBase * scaleY);

          double floatOffset = 5 * sin(animationValue * 2 * pi + (nivel * 0.5));
          pos = Offset(pos.dx, pos.dy + floatOffset * scaleY);

          Color pColor = _hexToColor(planetData['color'] ?? '#ffffff');
          String pSimbolo = planetData['simbolo'] ?? planetData['symbol'] ?? '🪐';
          double mag = (planetData['magnitude'] ?? 0.0).toDouble();
          double radius = (16 + (mag < 0 ? mag.abs() * 4 : 0)) * scaleX;

          // Planeta Base
          canvas.drawCircle(pos, radius, pPaint..color = pColor);
          // Simbolo
          drawText(pSimbolo, pos + Offset(0, 6 * scaleY), radius + 4, Colors.white);
          // Nombre
          drawText(key.toString().toUpperCase(), pos + Offset(0, radius + 24 * scaleY), 14, pColor);
        }
      });
    }

    // --- 6. SOL y LUNA ---
    final solarData = data['solar'] as Map?;
    final solPosition = solarData != null ? (solarData['position'] ?? solarData) : null;
    double pSol = 0.5;
    if (solPosition is Map) {
      if (solPosition.containsKey('progress')) {
        pSol = (solPosition['progress'] ?? 0.5).toDouble();
      } else if (solPosition.containsKey('azimuth')) {
        double az = (solPosition['azimuth'] ?? 0.0).toDouble();
        
        // CORRECCIÓN DE MAPEADO:
        // El arco va de 90° (Izquierda/Este) a 270° (Derecha/Oeste)
        // Si el Azimut es 180° (Sur), pSol debe ser 0.5 (Centro)
        if (az >= 90 && az <= 270) {
          pSol = (az - 90) / 180;
        } else if (az > 270 || az < 90) {
          // Si está fuera del rango visible (noche o bajo horizonte)
          // Lo dejamos en los extremos para que no aparezca en el centro
          pSol = (az > 270) ? 1.0 : 0.0;
        }
        pSol = pSol.clamp(0.0, 1.0);
      }
    } 
    
    final lunarData = data['lunar'] as Map?;
    final lunaPosition = lunarData;
    double pLuna = 0.3;
    if (lunaPosition is Map) {
      if (lunaPosition.containsKey('progress')) {
        pLuna = (lunaPosition['progress'] ?? 0.3).toDouble();
      } else if (lunaPosition.containsKey('azimuth')) {
        double az = (lunaPosition['azimuth'] ?? 0.0).toDouble();
        if (az >= 90 && az <= 270) {
          pLuna = (az - 90) / 180;
        } else {
          pLuna = (az > 270) ? 1.0 : 0.0;
        }
        pLuna = pLuna.clamp(0.0, 1.0);
      }
    }

    final sPaint = Paint()..style = PaintingStyle.fill;
    final double solAlt = (solPosition is Map ? (solPosition['altitude'] ?? -1.0) : -1.0).toDouble();
    if (solAlt > 0) {
      Offset solPos = _getBezierPos(pSol, arcoAstroP0, arcoAstroP1, arcoAstroP2);
      double solRadius = (35 + 3 * sin(animationValue * 2 * pi)) * scaleX;
      double solFloat = 4 * cos(animationValue * 2 * pi);
      solPos = solPos + Offset(0, (solFloat - 40) * scaleY);
      canvas.drawCircle(solPos, solRadius, sPaint..color = _hexToColor('#fbbf24'));
      drawText("☀️ SOL (${solAlt.toStringAsFixed(1)}°)", solPos + Offset(0, (solRadius + 15) * scaleY), 16, _hexToColor('#fbbf24'));
    }

    final double lunaAlt = (lunarData != null ? (lunarData['altitude'] ?? (lunarData['position'] is Map ? lunarData['position']['altitude'] : -1.0)) : -1.0).toDouble();
    if (lunaAlt > 0) {
      Offset lunaPos = _getBezierPos(pLuna, arcoAstroP0, arcoAstroP1, arcoAstroP2);
      double lunaFloat = 4 * sin(animationValue * 2 * pi + pi/2);
      lunaPos = lunaPos + Offset(0, (lunaFloat - 40) * scaleY);
      canvas.drawCircle(lunaPos, 35 * scaleX, sPaint..color = _hexToColor('#e5e7eb'));
      drawText("🌙 LUNA (${lunaAlt.toStringAsFixed(1)}°)", lunaPos + Offset(0, 50 * scaleY), 14, _hexToColor('#e5e7eb'));
    }

  }

  @override
  bool shouldRepaint(covariant CelestialPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.data != data;
  }
}

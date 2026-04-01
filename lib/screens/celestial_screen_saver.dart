import 'package:flutter/material.dart';
import 'celestial_painter.dart';

class CelestialScreenSaver extends StatefulWidget {
  final Map<String, dynamic>? apiData;

  const CelestialScreenSaver({Key? key, this.apiData}) : super(key: key);

  @override
  State<CelestialScreenSaver> createState() => _CelestialScreenSaverState();
}

class _CelestialScreenSaverState extends State<CelestialScreenSaver> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si no hay data, devolvemos un fondo oscuro neutro en lugar de crashear
    if (widget.apiData == null || widget.apiData!.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF4FD0E7)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: CelestialPainter(
              data: widget.apiData!,
              animationValue: _controller.value,
            ),
          );
        },
      ),
    );
  }
}


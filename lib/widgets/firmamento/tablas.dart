import 'package:flutter/material.dart';

/// Tablas de los firmamentos que no vienen en la API (ver
/// `docs/prompt-app-flutter-observatorio-firmamentos.md`).

@immutable
class Signo {
  const Signo(this.nombre, this.glifo, this.color);

  final String nombre;
  final String glifo;
  final Color color;
}

/// Índice 0-11, como `signo` en la API.
const List<Signo> kSignos = [
  Signo('Aries', '♈', Color(0xFFFF6B6B)),
  Signo('Tauro', '♉', Color(0xFF51CF66)),
  Signo('Géminis', '♊', Color(0xFFFFD43B)),
  Signo('Cáncer', '♋', Color(0xFF74C0FC)),
  Signo('Leo', '♌', Color(0xFFFF8CC8)),
  Signo('Virgo', '♍', Color(0xFF69DB7C)),
  Signo('Libra', '♎', Color(0xFF91A7FF)),
  Signo('Escorpio', '♏', Color(0xFFB86B6B)),
  Signo('Sagitario', '♐', Color(0xFFFFA94D)),
  Signo('Capricornio', '♑', Color(0xFF8CE99A)),
  Signo('Acuario', '♒', Color(0xFF74C0FC)),
  Signo('Piscis', '♓', Color(0xFFD0BFFF)),
];

/// Pide la presentación de texto (U+FE0E) y no el emoji de color, que trae
/// su propia paleta. Igual que `ZodiacTables::asText()` en el servidor.
String glifoTexto(String glifo) => '$glifo\u{FE0E}';

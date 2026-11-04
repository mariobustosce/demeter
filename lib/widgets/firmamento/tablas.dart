import 'package:flutter/material.dart';

/// Tablas de los firmamentos que no vienen en la API (ver
/// `docs/prompt-app-flutter-observatorio-firmamentos.md`).

// Paleta de la app (los mismos valores que las pantallas actuales).
const kFondo = Color(0xFF0A0A0F);
const kTarjeta = Color(0xFF15151D);
const kCian = Color(0xFF4FD0E7);
const kVioleta = Color(0xFF8B5CF6);
const kTexto = Color(0xFFF7FAFC);
const kTextoTenue = Color(0xFF94A3B8);
const kAmbar = Color(0xFFF59E0B);

@immutable
class Signo {
  const Signo(this.nombre, this.glifo, this.color, this.elemento, this.modalidad);

  final String nombre;
  final String glifo;
  final Color color;
  final String elemento;
  final String modalidad;
}

/// Índice 0-11, como `signo` en la API.
const List<Signo> kSignos = [
  Signo('Aries', '♈', Color(0xFFFF6B6B), 'Fuego', 'Cardinal'),
  Signo('Tauro', '♉', Color(0xFF51CF66), 'Tierra', 'Fijo'),
  Signo('Géminis', '♊', Color(0xFFFFD43B), 'Aire', 'Mutable'),
  Signo('Cáncer', '♋', Color(0xFF74C0FC), 'Agua', 'Cardinal'),
  Signo('Leo', '♌', Color(0xFFFF8CC8), 'Fuego', 'Fijo'),
  Signo('Virgo', '♍', Color(0xFF69DB7C), 'Tierra', 'Mutable'),
  Signo('Libra', '♎', Color(0xFF91A7FF), 'Aire', 'Cardinal'),
  Signo('Escorpio', '♏', Color(0xFFB86B6B), 'Agua', 'Fijo'),
  Signo('Sagitario', '♐', Color(0xFFFFA94D), 'Fuego', 'Mutable'),
  Signo('Capricornio', '♑', Color(0xFF8CE99A), 'Tierra', 'Cardinal'),
  Signo('Acuario', '♒', Color(0xFF74C0FC), 'Aire', 'Fijo'),
  Signo('Piscis', '♓', Color(0xFFD0BFFF), 'Agua', 'Mutable'),
];

Signo signoDe(int i) => kSignos[i.clamp(0, 11)];

/// Anillo de la rueda y barras del reparto.
const Map<String, Color> kElementos = {
  'Fuego': Color(0xFFF0783C),
  'Tierra': Color(0xFF7BBF6A),
  'Aire': Color(0xFFE8C34A),
  'Agua': Color(0xFF5AA6D8),
};

// Badges: los mismos tonos de los aspectos.
const Map<String, ({String nombre, Color color})> kDignidades = {
  'domicile': (nombre: 'Domicilio', color: Color(0xFF5FD48A)),
  'exaltation': (nombre: 'Exaltación', color: Color(0xFFF5D76E)),
  'detriment': (nombre: 'Exilio', color: Color(0xFFFF9A3C)),
  'fall': (nombre: 'Caída', color: Color(0xFFFF5D5D)),
};
const kColorR = Color(0xFFFF9E8A);
const kColorE = Color(0xFF9FB0C4);
const kColorOob = Color(0xFFC9A0FF);

/// Ejes: AC y DC lila, MC e IC rosa.
const kColorAcDc = Color(0xFFC4B5FD);
const kColorMcIc = Color(0xFFF0ABFC);

const Map<String, ({String sigla, String nombre, Color color})> kEjes = {
  'asc': (sigla: 'AC', nombre: 'Ascendente', color: kColorAcDc),
  'dsc': (sigla: 'DC', nombre: 'Descendente', color: kColorAcDc),
  'mc': (sigla: 'MC', nombre: 'Medio Cielo', color: kColorMcIc),
  'ic': (sigla: 'IC', nombre: 'Fondo del Cielo', color: kColorMcIc),
};

const Map<String, String> kRudhyar = {
  'new': 'Nueva',
  'crescent': 'Creciente',
  'first_quarter': 'Cuarto creciente',
  'gibbous': 'Gibosa',
  'full': 'Llena',
  'disseminating': 'Diseminante',
  'last_quarter': 'Cuarto menguante',
  'balsamic': 'Balsámica',
};

const Map<String, String> kTipoEclipse = {
  'total': 'total',
  'partial': 'parcial',
  'annular': 'anular',
  'hybrid': 'híbrido',
  'penumbral': 'penumbral',
};

const List<String> kRomanos = [
  'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII',
];

/// Casa 1-12 en romano.
String romano(int casa) => casa >= 1 && casa <= 12 ? kRomanos[casa - 1] : '—';

/// Pide la presentación de texto (U+FE0E) y no el emoji de color, que trae
/// su propia paleta. Igual que `ZodiacTables::asText()` en el servidor.
String glifoTexto(String glifo) => '$glifo\u{FE0E}';

/// Grados y minutos dentro del signo, como `17°55′`.
String gradoMinutos(double grados) {
  final g = grados.abs();
  var d = g.floor();
  var m = ((g - d) * 60).floor();
  if (m == 60) {
    d += 1;
    m = 0;
  }
  return '$d°${m.toString().padLeft(2, '0')}′';
}

/// `#RRGGBB` del servidor, o [respaldo] si no se entiende.
Color colorHex(Object? hex, {Color respaldo = kTextoTenue}) {
  if (hex is! String) return respaldo;
  final h = hex.replaceFirst('#', '');
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? respaldo : Color(v);
}

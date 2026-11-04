/// Separación mínima entre glifos de la rueda, en grados de pantalla.
const double kSeparacionGlifos = 12.5;

double _mod360(double x) => ((x % 360) + 360) % 360;

/// Reparte los glifos para que no se encimen. Es el algoritmo de
/// `carta-rueda.blade.php`:
///
/// 1. ordena por ángulo y corta el anillo por el hueco mayor (así se vuelve
///    una recta y el orden no puede invertirse);
/// 2. empuja hacia delante a los que queden a menos de [sep];
/// 3. devuelve el grupo a su centro de masa.
///
/// Recibe y devuelve ángulos de pantalla en el mismo orden.
List<double> separarGlifos(List<double> angulos, {double sep = kSeparacionGlifos}) {
  final n = angulos.length;
  final pos = [for (final a in angulos) _mod360(a)];
  if (n < 2 || n * sep >= 350) return pos;

  final orden = List<int>.generate(n, (i) => i)..sort((x, y) => pos[x].compareTo(pos[y]));

  // El hueco mayor entre vecinos: ahí se corta.
  var corte = 0;
  var hueco = -1.0;
  for (var i = 0; i < n; i++) {
    final g = _mod360(pos[orden[(i + 1) % n]] - pos[orden[i]]);
    if (g > hueco) {
      hueco = g;
      corte = (i + 1) % n;
    }
  }
  final recta = [for (var k = 0; k < n; k++) orden[(corte + k) % n]];

  final base = pos[recta.first];
  final lin = [for (final i in recta) base + _mod360(pos[i] - base)];
  final original = List<double>.of(lin);

  for (var k = 1; k < n; k++) {
    if (lin[k] - lin[k - 1] < sep) lin[k] = lin[k - 1] + sep;
  }

  final desvio = (lin.fold<double>(0, (s, v) => s + v) -
          original.fold<double>(0, (s, v) => s + v)) /
      n;
  final salida = List<double>.filled(n, 0);
  for (var k = 0; k < n; k++) {
    salida[recta[k]] = _mod360(lin[k] - desvio);
  }
  return salida;
}

/// Distancia angular más corta entre dos ángulos (0-180).
double distanciaAngular(double a, double b) {
  final d = _mod360(a - b);
  return d > 180 ? 360 - d : d;
}

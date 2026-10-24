/// Modos del mapa kiosk. El nombre es el segmento de la URL
/// (`/app/mapa/{modo}`).
enum MapMode {
  basico('Básico'),
  profesional('Profesional'),
  astronomico('Astronómico');

  const MapMode(this.label);

  final String label;

  /// El modo guardado, o básico si no hay uno válido.
  static MapMode fromName(String? name) =>
      values.firstWhere((m) => m.name == name, orElse: () => basico);
}

/// Un lugar favorito, con lo que necesita el mapa. Las coordenadas no se leen:
/// el mapa lo abre por su id y el servidor las saca del token.
class Favorite {
  const Favorite({required this.id, required this.title});

  final int id;
  final String title;

  /// `null` si le falta el id.
  static Favorite? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! num) return null;
    final title = '${json['titulo'] ?? ''}'.trim();
    return Favorite(id: id.toInt(), title: title.isEmpty ? 'Mi lugar' : title);
  }
}

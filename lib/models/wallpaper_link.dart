/// Modos del fondo animado: los del mapa y el rotativo, que cambia de paisaje
/// cada 5 minutos y se desbloquea por favorito. El nombre es el segmento de la
/// URL (`/lively/m/{token}/{modo}`).
enum WallpaperMode {
  basico('Básico'),
  profesional('Profesional'),
  astronomico('Astronómico'),
  rotativo('Rotativo');

  const WallpaperMode(this.label);

  final String label;

  /// `null` si no es un modo conocido.
  static WallpaperMode? fromName(String? name) =>
      values.where((m) => m.name == name).firstOrNull;
}

/// El fondo animado de un favorito (`Fondo` en `/api/favoritos/{id}/fondo`).
/// Su token es el del enlace Lively del favorito: el mismo del PC.
class WallpaperLink {
  const WallpaperLink({
    required this.exists,
    this.urls = const {},
    this.canCreate = true,
    this.rotatingUnlocked = false,
    this.rotatingPrice,
  });

  final bool exists;

  /// Una URL por modo, sin `?ratio=` (lo pone el servicio). El rotativo solo
  /// está si se desbloqueó. Sin fondo, vacío.
  final Map<WallpaperMode, String> urls;

  /// `false`: el servidor no deja crear el fondo (hoy siempre `true`).
  final bool canCreate;
  final bool rotatingUnlocked;

  /// En polvo estelar.
  final int? rotatingPrice;

  factory WallpaperLink.fromJson(Map<String, dynamic> json) {
    final rawUrls = json['urls'];
    final rotating = json['rotativo'];
    final price = rotating is Map ? rotating['precio'] : null;
    return WallpaperLink(
      exists: json['existe'] == true,
      // Sin fondo llega `{}`; se acepta también una lista vacía.
      urls: {
        if (rawUrls is Map)
          for (final entry in rawUrls.entries)
            if (WallpaperMode.fromName('${entry.key}') case final mode?)
              if (entry.value is String && (entry.value as String).isNotEmpty)
                mode: entry.value as String,
      },
      canCreate: json['puede_crear'] != false,
      rotatingUnlocked: rotating is Map && rotating['desbloqueado'] == true,
      rotatingPrice: price is num ? price.toInt() : null,
    );
  }
}

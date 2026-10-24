import 'package:flutter/foundation.dart';

/// Un paisaje del catálogo de «Mis paisajes» (`GET /api/paisajes`).
@immutable
class Landscape {
  const Landscape({
    required this.key,
    required this.title,
    this.description = '',
    this.isDefault = false,
    this.isPremium = false,
    this.price,
    this.purchased = false,
    this.canUse = true,
    this.thumbnailUrl,
  });

  /// La `clave`: es lo que se manda al servidor.
  final String key;
  final String title;
  final String description;

  /// «El de siempre»: el que usa un favorito sin paisaje elegido.
  final bool isDefault;
  final bool isPremium;

  /// En polvo estelar; `null` si no está a la venta.
  final int? price;
  final bool purchased;

  /// Con `false` va con 🔒: hay que comprarlo para usarlo.
  final bool canUse;

  /// SVG público, sin token.
  final String? thumbnailUrl;

  bool get locked => !canUse;

  /// `null` si le falta la clave.
  static Landscape? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['clave'];
    if (key is! String || key.isEmpty) return null;
    final title = '${json['titulo'] ?? ''}'.trim();
    final price = json['precio_polvo'];
    final thumbnail = json['miniatura_url'];
    return Landscape(
      key: key,
      title: title.isEmpty ? key : title,
      description: '${json['descripcion'] ?? ''}'.trim(),
      isDefault: json['es_defecto'] == true,
      isPremium: json['es_premium'] == true,
      price: price is num ? price.toInt() : null,
      purchased: json['comprado'] == true,
      canUse: json['puede_usar'] != false,
      thumbnailUrl: thumbnail is String && thumbnail.isNotEmpty ? thumbnail : null,
    );
  }
}

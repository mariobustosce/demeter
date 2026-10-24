/// Un paisaje como lo manda `GET /api/paisajes`.
Map<String, Object?> landscapeJson(
  String key, {
  bool premium = false,
  bool canUse = true,
  bool purchased = false,
  bool isDefault = false,
}) =>
    {
      'clave': key,
      'titulo': 'Paisaje $key',
      'descripcion': 'Descripción de $key',
      'es_defecto': isDefault,
      'es_premium': premium,
      'precio_polvo': premium ? 100 : null,
      'comprado': purchased,
      'puede_usar': canUse,
      'miniatura_url': 'https://windowsdemeter.com/paisajes/$key/miniatura',
    };

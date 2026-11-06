/// Un paquete de polvo estelar que se vende en Google Play o en la App Store.
/// El precio no viene aquí: se muestra el de la tienda (`ProductDetails`), no
/// el de la web.
class StorePackage {
  final int id;
  final String name;
  final int coins;
  final String icon;
  final String color;
  final String description;
  final bool highlight;

  /// El producto en Play Console o App Store Connect (`polvo_100`…).
  final String productId;

  const StorePackage({
    required this.id,
    required this.name,
    required this.coins,
    required this.icon,
    required this.color,
    required this.description,
    required this.highlight,
    required this.productId,
  });

  /// `null` si no se vende en esa tienda. [campoProducto] es
  /// `google_play_product_id` o `app_store_product_id`.
  static StorePackage? fromJson(
    Object? json, {
    String campoProducto = 'google_play_product_id',
  }) {
    if (json is! Map) return null;
    final productId = json[campoProducto]?.toString() ?? '';
    if (productId.isEmpty) return null;
    return StorePackage(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Pack',
      coins: int.tryParse(json['coins']?.toString() ?? '0') ?? 0,
      icon: json['icon']?.toString() ?? 'sparkles',
      color: json['color']?.toString() ?? 'blue',
      description: json['description']?.toString() ?? '',
      highlight: json['highlight'] == true,
      productId: productId,
    );
  }
}

/// Los paquetes de la tienda y la cuenta que pide el servidor en cada compra.
class StoreCatalog {
  const StoreCatalog({required this.accountId, required this.packages});

  /// `obfuscatedAccountId` en Play, `appAccountToken` en la App Store. Se
  /// pide de nuevo antes de cada compra.
  final String? accountId;
  final List<StorePackage> packages;
}

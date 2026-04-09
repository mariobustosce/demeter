class StorePackage {
  final int id;
  final String name;
  final int coins;
  final int priceClp;
  final String currency;
  final String icon;
  final String color;
  final String description;
  final bool highlight;

  const StorePackage({
    required this.id,
    required this.name,
    required this.coins,
    required this.priceClp,
    required this.currency,
    required this.icon,
    required this.color,
    required this.description,
    required this.highlight,
  });

  factory StorePackage.fromJson(Map<String, dynamic> json) {
    return StorePackage(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Pack',
      coins: int.tryParse(json['coins']?.toString() ?? '0') ?? 0,
      priceClp: int.tryParse(json['price_clp']?.toString() ?? '0') ?? 0,
      currency: json['currency']?.toString() ?? 'CLP',
      icon: json['icon']?.toString() ?? 'sparkles',
      color: json['color']?.toString() ?? 'blue',
      description: json['description']?.toString() ?? '',
      highlight: json['highlight'] == true,
    );
  }
}

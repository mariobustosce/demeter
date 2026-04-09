class CheckoutOrder {
  final int id;
  final String externalReference;
  final String status;
  final int amountClp;
  final int coinsAmount;

  const CheckoutOrder({
    required this.id,
    required this.externalReference,
    required this.status,
    required this.amountClp,
    required this.coinsAmount,
  });

  factory CheckoutOrder.fromJson(Map<String, dynamic> json) {
    return CheckoutOrder(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      externalReference: json['external_reference']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      amountClp: int.tryParse(json['amount_clp']?.toString() ?? '0') ?? 0,
      coinsAmount: int.tryParse(json['coins_amount']?.toString() ?? '0') ?? 0,
    );
  }
}

import 'checkout_order.dart';

class OrderStatusResponse {
  final int id;
  final String externalReference;
  final String status;
  final int amountClp;
  final int coinsAmount;
  final String? paymentMethod;
  final String? mercadoPagoId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OrderStatusResponse({
    required this.id,
    required this.externalReference,
    required this.status,
    required this.amountClp,
    required this.coinsAmount,
    this.paymentMethod,
    this.mercadoPagoId,
    this.createdAt,
    this.updatedAt,
  });

  factory OrderStatusResponse.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? json;

    return OrderStatusResponse(
      id: int.tryParse(data['id']?.toString() ?? '0') ?? 0,
      externalReference: data['external_reference']?.toString() ?? '',
      status: data['status']?.toString() ?? 'pending',
      amountClp: int.tryParse(data['amount_clp']?.toString() ?? '0') ?? 0,
      coinsAmount: int.tryParse(data['coins_amount']?.toString() ?? '0') ?? 0,
      paymentMethod: data['payment_method']?.toString(),
      mercadoPagoId: data['mercado_pago_id']?.toString(),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
    );
  }

  factory OrderStatusResponse.fromCheckoutOrder(CheckoutOrder order) {
    return OrderStatusResponse(
      id: order.id,
      externalReference: order.externalReference,
      status: order.status,
      amountClp: order.amountClp,
      coinsAmount: order.coinsAmount,
    );
  }

  bool get isFinished =>
      status == 'approved' || status == 'rejected' || status == 'cancelled';
}

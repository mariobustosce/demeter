import 'checkout_order.dart';
import 'checkout_payload.dart';
import 'store_package.dart';

class CheckoutResponse {
  final String status;
  final String message;
  final CheckoutOrder order;
  final StorePackage package;
  final CheckoutPayload checkout;

  const CheckoutResponse({
    required this.status,
    required this.message,
    required this.order,
    required this.package,
    required this.checkout,
  });

  factory CheckoutResponse.fromJson(Map<String, dynamic> json) {
    final data =
        (json['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    return CheckoutResponse(
      status: json['status']?.toString() ?? 'success',
      message: json['message']?.toString() ?? '',
      order: CheckoutOrder.fromJson(
        (data['order'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      ),
      package: StorePackage.fromJson(
        (data['package'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      ),
      checkout: CheckoutPayload.fromJson(
        (data['checkout'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      ),
    );
  }
}

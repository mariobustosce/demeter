import '../models/checkout_response.dart';
import '../models/order_status_response.dart';
import '../models/store_package.dart';
import 'api_client.dart';

class StoreService {
  ApiClient get _api => ApiClient.instance;

  Future<List<StorePackage>> getPackages() async {
    final body = jsonMap(await _api.get('/store/packages'));
    final data = (body['data'] as List?) ?? const [];
    return data
        .whereType<Map>()
        .map((item) => StorePackage.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<CheckoutResponse> createCheckout(int packageId) async {
    final body = await _api.post(
      '/store/checkout',
      body: {'package_id': packageId},
    );
    return CheckoutResponse.fromJson(jsonMap(body));
  }

  Future<OrderStatusResponse> getOrderStatus(String externalReference) async {
    final reference = Uri.encodeComponent(externalReference);
    final body = await _api.get('/store/orders/$reference');
    return OrderStatusResponse.fromJson(jsonMap(body));
  }
}

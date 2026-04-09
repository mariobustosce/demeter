import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/checkout_response.dart';
import '../models/order_status_response.dart';
import '../models/store_package.dart';
import '../models/user.dart';
import '../services/profile_service.dart';
import '../services/store_service.dart';

const backgroundColor = Color(0xFF0A0A0F);
const accentCyan = Color(0xFF4FD0E7);
const accentPurple = Color(0xFF8B5CF6);
const cardBackground = Color(0xEF0F172A);
const textColor = Color(0xFFF7FAFC);
const secondaryTextColor = Color(0xFF94A3B8);

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with WidgetsBindingObserver {
  final StoreService _storeService = StoreService();
  final ProfileService _profileService = ProfileService();

  bool _isLoading = true;
  bool _isCreatingCheckout = false;
  List<StorePackage> _packages = [];
  User? _user;
  CheckoutResponse? _checkoutResponse;
  OrderStatusResponse? _pendingOrder;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _pendingOrder != null &&
        !_pendingOrder!.isFinished) {
      _refreshPendingOrder(silent: false);
    }
  }

  Future<void> _loadStore() async {
    setState(() => _isLoading = true);

    try {
      final user = await _profileService.getProfile();
      final packages = await _storeService.getPackages();

      if (!mounted) return;

      setState(() {
        _user = user;
        _packages = packages;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_readableError(error)),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  String _readableError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _startCheckout(StorePackage package) async {
    setState(() => _isCreatingCheckout = true);

    try {
      final response = await _storeService.createCheckout(package.id);
      final uri = Uri.tryParse(response.checkout.initPoint);

      setState(() {
        _checkoutResponse = response;
        _pendingOrder = OrderStatusResponse.fromCheckoutOrder(response.order);
      });

      _startPolling();

      if (uri == null) {
        throw Exception('La URL de checkout no es válida.');
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('No se pudo abrir Mercado Pago desde el dispositivo.');
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_readableError(error)),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingCheckout = false);
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshPendingOrder(silent: true);
    });
  }

  Future<void> _refreshPendingOrder({required bool silent}) async {
    final externalReference =
        _pendingOrder?.externalReference ??
        _checkoutResponse?.checkout.externalReference;
    if (externalReference == null || externalReference.isEmpty) {
      return;
    }

    try {
      final order = await _storeService.getOrderStatus(externalReference);
      if (!mounted) return;

      final previousStatus = _pendingOrder?.status;
      setState(() {
        _pendingOrder = order;
      });

      if (order.isFinished) {
        _pollTimer?.cancel();
        final refreshedUser = await _profileService.getProfile();
        if (!mounted) return;

        setState(() {
          _user = refreshedUser;
        });

        if (previousStatus != order.status || !silent) {
          _showOrderStatusMessage(order);
        }
      }
    } catch (error) {
      if (!mounted || silent) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_readableError(error)),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showOrderStatusMessage(OrderStatusResponse order) {
    Color background;
    String text;

    switch (order.status) {
      case 'approved':
        background = Colors.green;
        text = 'Compra aprobada. Tu saldo ya fue actualizado.';
        break;
      case 'rejected':
        background = Colors.redAccent;
        text = 'La compra fue rechazada.';
        break;
      case 'cancelled':
        background = Colors.orange;
        text = 'La compra fue cancelada.';
        break;
      default:
        background = accentPurple;
        text = 'La compra sigue pendiente.';
        break;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text), backgroundColor: background));
  }

  IconData _iconForPackage(String iconName) {
    switch (iconName) {
      case 'star':
        return Icons.star_rounded;
      case 'globe-alt':
        return Icons.public_rounded;
      case 'sparkles':
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  Color _colorForPackage(String colorName) {
    switch (colorName) {
      case 'purple':
        return accentPurple;
      case 'amber':
        return Colors.amber;
      case 'blue':
      default:
        return accentCyan;
    }
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentCyan.withOpacity(0.18),
            accentPurple.withOpacity(0.22),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentCyan.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Polvo Estelar Disponible',
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 12,
              letterSpacing: 1,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_user?.celestialCoins ?? 0}',
            style: const TextStyle(
              color: textColor,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Las compras se acreditan solo cuando Mercado Pago confirma el pago.',
            style: TextStyle(color: secondaryTextColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard() {
    if (_pendingOrder == null) {
      return const SizedBox.shrink();
    }

    final order = _pendingOrder!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentPurple.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: accentPurple),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Orden ${order.externalReference}',
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Estado: ${order.status}',
            style: const TextStyle(color: secondaryTextColor),
          ),
          Text(
            'Monto: CLP ${_formatPrice(order.amountClp)}',
            style: const TextStyle(color: secondaryTextColor),
          ),
          Text(
            'Polvo: ${order.coinsAmount}',
            style: const TextStyle(color: secondaryTextColor),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _refreshPendingOrder(silent: false),
                  icon: const Icon(Icons.refresh, color: accentCyan),
                  label: const Text(
                    'Revisar estado',
                    style: TextStyle(color: accentCyan),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: accentCyan.withOpacity(0.35)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _checkoutResponse == null
                      ? null
                      : () async {
                          final uri = Uri.tryParse(
                            _checkoutResponse!.checkout.initPoint,
                          );
                          if (uri != null) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                  icon: const Icon(Icons.open_in_new, color: backgroundColor),
                  label: const Text(
                    'Abrir checkout',
                    style: TextStyle(color: backgroundColor),
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: accentCyan),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(StorePackage package) {
    final color = _colorForPackage(package.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(package.highlight ? 0.55 : 0.2),
          width: package.highlight ? 1.4 : 1,
        ),
        boxShadow: package.highlight
            ? [
                BoxShadow(
                  color: color.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_iconForPackage(package.icon), color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          package.name,
                          style: const TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (package.highlight) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'MEJOR VALOR',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      package.description,
                      style: const TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                '${package.coins} ✨',
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                'CLP ${_formatPrice(package.priceClp)}',
                style: const TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCreatingCheckout
                  ? null
                  : () => _startCheckout(package),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: backgroundColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isCreatingCheckout
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: backgroundColor,
                      ),
                    )
                  : const Text(
                      'Comprar con Mercado Pago',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: const Text(
          'Tienda Astral',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loadStore,
            icon: const Icon(Icons.refresh, color: accentCyan),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentCyan))
          : RefreshIndicator(
              onRefresh: _loadStore,
              color: accentCyan,
              backgroundColor: cardBackground,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 18),
                  _buildPendingCard(),
                  if (_pendingOrder != null) const SizedBox(height: 18),
                  const Text(
                    'Packs disponibles',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Selecciona un pack y completa la compra en Mercado Pago. Luego vuelve a la app para verificar el estado.',
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  ..._packages.map(_buildPackageCard),
                ],
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/store_package.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../services/coin_balance.dart';
import '../services/store_service.dart';

const backgroundColor = Color(0xFF0A0A0F);
const accentCyan = Color(0xFF4FD0E7);
const accentPurple = Color(0xFF8B5CF6);
const cardBackground = Color(0xEF0F172A);
const textColor = Color(0xFFF7FAFC);
const secondaryTextColor = Color(0xFF94A3B8);

/// Un paquete del servidor con su producto de Play, que trae el precio.
typedef _Offer = ({StorePackage package, ProductDetails product});

/// Compra de polvo estelar con Google Play. El resultado de cada compra lo
/// avisa la app entera (main.dart), aunque se cierre esta pantalla.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, this.billing, this.store});

  final BillingService? billing;
  final StoreService? store;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  late final BillingService _billing = widget.billing ?? BillingService.instance;
  late final StoreService _store = widget.store ?? StoreService();

  // DECISIÓN PENDIENTE antes de la App Store: Apple exige su propio sistema
  // de pago para bienes digitales, y el servidor solo verifica compras de
  // Google Play. Mientras tanto, en iOS se ve el saldo y se gasta, pero no se
  // vende nada.
  bool get _canBuy => _billing.available;

  bool _isLoading = true;
  String? _error;
  List<_Offer> _offers = [];

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // El saldo pudo cambiar en la web. getMe no lanza.
    final balance = AuthService().getMe();
    try {
      if (_canBuy) {
        final catalog = await _store.catalog();
        final products = await _billing.products({
          for (final package in catalog.packages) package.productId,
        });
        // Un paquete que Play aún no tiene (o no publicó) no se muestra.
        _offers = [
          for (final package in catalog.packages)
            if (products[package.productId] case final product?)
              (package: package, product: product),
        ];
      }
    } catch (error) {
      _error = error.toString();
    }
    await balance;

    if (!mounted) return;
    setState(() => _isLoading = false);
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

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentCyan.withValues(alpha: 0.18),
            accentPurple.withValues(alpha: 0.22),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentCyan.withValues(alpha: 0.18)),
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
          ValueListenableBuilder<int?>(
            valueListenable: coinBalance,
            builder: (context, coins, _) => Text(
              coins == null ? '—' : '$coins',
              style: const TextStyle(
                color: textColor,
                fontSize: 34,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (_canBuy) ...[
            const SizedBox(height: 6),
            const Text(
              'Las compras se acreditan cuando el servidor las confirma con '
              'Google Play.',
              style: TextStyle(color: secondaryTextColor, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPackageCard(_Offer offer, String? buying) {
    final package = offer.package;
    final color = _colorForPackage(package.color);
    final isBuyingThis = buying == package.productId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: package.highlight ? 0.55 : 0.2),
          width: package.highlight ? 1.4 : 1,
        ),
        boxShadow: package.highlight
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.12),
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
                  color: color.withValues(alpha: 0.12),
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
                        Flexible(
                          child: Text(
                            package.name,
                            style: const TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
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
                              color: Colors.amber.withValues(alpha: 0.12),
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
                    if (package.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        package.description,
                        style: const TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
              // El de Play, en la moneda del usuario.
              Text(
                offer.product.price,
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
              onPressed: buying != null
                  ? null
                  : () => _billing.buy(offer.product),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: backgroundColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: isBuyingThis
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: backgroundColor,
                      ),
                    )
                  : const Text(
                      'Comprar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOffers() {
    if (_error != null) {
      return [
        Text(_error!, style: const TextStyle(color: secondaryTextColor)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _loadStore,
            icon: const Icon(Icons.refresh, color: accentCyan),
            label: const Text(
              'Reintentar',
              style: TextStyle(color: accentCyan),
            ),
          ),
        ),
      ];
    }
    if (_offers.isEmpty) {
      return const [
        Text(
          'Por ahora no hay packs a la venta. Vuelve a intentarlo más tarde.',
          style: TextStyle(color: secondaryTextColor),
        ),
      ];
    }
    return [
      ValueListenableBuilder<String?>(
        valueListenable: _billing.buying,
        builder: (context, buying, _) => Column(
          children: [
            for (final offer in _offers) _buildPackageCard(offer, buying),
          ],
        ),
      ),
    ];
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
                  if (!_canBuy)
                    const Text(
                      'Por ahora el polvo estelar no se vende en iPhone. '
                      'Puedes usar el que ya tienes.',
                      style: TextStyle(color: secondaryTextColor),
                    )
                  else ...[
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
                      'El pago lo hace Google Play, en tu moneda.',
                      style: TextStyle(color: secondaryTextColor, fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    ..._buildOffers(),
                  ],
                ],
              ),
            ),
    );
  }
}

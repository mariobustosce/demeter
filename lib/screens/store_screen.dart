import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/referral_payload.dart';
import '../models/store_package.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../services/coin_balance.dart';
import '../services/profile_service.dart';
import '../services/store_service.dart';
import '../textos/tienda_textos.dart';
import '../theme/consultas_theme.dart';
import '../widgets/consultas/cns_basicos.dart';
import '../widgets/consultas/fondo_consultas.dart';

/// Un paquete del servidor con su producto de la tienda, que trae el precio.
typedef _Offer = ({StorePackage package, ProductDetails product});

// Colores de la tienda web que no están en los tokens de Consultas.
const _ambar = Color(0xFFF59E0B);
const _verde = Color(0xFF22C55E);
const _esmeralda = Color(0xFF10B981);
const _amarillo = Color(0xFFFACC15);
const _lila = Color(0xFFD8B4FE);
const _lilaTenue = Color(0xFFE9D5FF);
const _morado = Color(0xFF581C87);

/// La Tienda Estelar con la estética de la web. El resultado de cada compra
/// lo avisa la app entera (main.dart), aunque se cierre esta pantalla.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, this.billing, this.store, this.profile});

  final BillingService? billing;
  final StoreService? store;
  final ProfileService? profile;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  late final BillingService _billing = widget.billing ?? BillingService.instance;
  late final StoreService _store = widget.store ?? StoreService();
  late final ProfileService _profile = widget.profile ?? ProfileService();

  // Falso solo fuera de Android e iOS.
  bool get _canBuy => _billing.available;

  bool _isLoading = true;
  String? _error;
  List<_Offer> _offers = [];
  ReferralPayload? _referral;
  bool _copiado = false;
  Timer? _copiadoTimer;

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  @override
  void dispose() {
    _copiadoTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStore() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // El saldo pudo cambiar en la web. Ni getMe ni el referido lanzan.
    final balance = AuthService().getMe();
    final referral = _profile.getReferralPayload();
    try {
      if (_canBuy) {
        final catalog = await _store.catalog();
        final products = await _billing.products({
          for (final package in catalog.packages) package.productId,
        });
        // Un paquete que la tienda aún no tiene (o no publicó) no se muestra.
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
    final payload = await referral;
    _referral = payload != null && payload.referralCode.isNotEmpty ? payload : null;

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _copiar(String codigo) async {
    await Clipboard.setData(ClipboardData(text: codigo));
    if (!mounted) return;
    setState(() => _copiado = true);
    _copiadoTimer?.cancel();
    _copiadoTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiado = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final telefono = MediaQuery.sizeOf(context).width < CnsEspacios.anchoTelefono;
    final lado = telefono ? CnsEspacios.l : 20.0;

    return Scaffold(
      backgroundColor: CnsColores.fondoA,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: CnsColores.transparente,
        elevation: 0,
        foregroundColor: CnsColores.texto,
        actions: [
          IconButton(
            onPressed: _loadStore,
            tooltip: TxTienda.reintentar,
            icon: const Icon(Icons.refresh, color: CnsColores.cian),
          ),
        ],
      ),
      body: FondoConsultas(
        child: SafeArea(
          bottom: false,
          child: _isLoading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: CnsColores.cian),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStore,
                  color: CnsColores.cian,
                  backgroundColor: CnsColores.hoja,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(lado, kToolbarHeight, lado, 48),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _cabecera(),
                              const SizedBox(height: 24),
                              _saldo(),
                              const SizedBox(height: 24),
                              ..._paquetes(),
                              if (_referral case final r?) ...[
                                const SizedBox(height: 40),
                                _referido(r),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _cabecera() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(TxTienda.cejilla.toUpperCase(), style: CnsTipos.cejilla()),
        const SizedBox(height: 10),
        Text(TxTienda.tituloLinea1, style: CnsTipos.serifStyle(size: 30, height: 1.12)),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => const LinearGradient(
            colors: CnsColores.tituloDegradado,
            stops: [0, .45, 1],
          ).createShader(r),
          child: Text(
            TxTienda.tituloLinea2,
            style: CnsTipos.serifStyle(size: 30, height: 1.12, style: FontStyle.italic),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          TxTienda.lema,
          style: TextStyle(fontSize: 14.4, height: 1.7, color: CnsColores.slate300.withValues(alpha: .66)),
        ),
      ],
    );
  }

  /// Como el resumen de Consultas: rótulo a la izquierda, cifra ámbar grande.
  Widget _saldo() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CnsRadios.resumen),
        border: Border.all(color: CnsColores.slate(.14)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [CnsColores.resumenA, CnsColores.resumenB],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(TxTienda.saldo.toUpperCase(), style: CnsTipos.cejilla(size: 10, tracking: .2)),
          ),
          ValueListenableBuilder<int?>(
            valueListenable: coinBalance,
            builder: (context, coins, _) => Text(
              coins == null ? '—' : '${miles(coins)} ✨',
              key: const ValueKey('tienda-saldo'),
              style: const TextStyle(
                fontSize: 29,
                height: 1,
                fontWeight: FontWeight.w600,
                color: CnsColores.ambar,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _paquetes() {
    if (!_canBuy) {
      return [_nota(TxTienda.noSeVendeAqui)];
    }
    if (_error != null) {
      return [
        CnsPunteado(
          radio: CnsRadios.consola,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: CnsColores.slate(.8)),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _loadStore, child: const Text(TxTienda.reintentar)),
            ],
          ),
        ),
      ];
    }
    if (_offers.isEmpty) {
      return [_nota(TxTienda.sinPaquetes)];
    }
    return [
      ValueListenableBuilder<String?>(
        valueListenable: _billing.buying,
        builder: (context, buying, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final offer in _offers)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _PaqueteCard(
                  offer: offer,
                  buying: buying,
                  onComprar: () => _billing.buy(offer.product),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      _pagoSeguro(),
    ];
  }

  Widget _nota(String texto) {
    return CnsPunteado(
      radio: CnsRadios.consola,
      fondo: CnsColores.velo,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, height: 1.6, color: CnsColores.slate300.withValues(alpha: .75)),
      ),
    );
  }

  Widget _pagoSeguro() {
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: CnsColores.velo,
        borderRadius: BorderRadius.circular(CnsRadios.casilla),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user_outlined, size: 20, color: _verde),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              ios ? TxTienda.pagoSeguroAppStore : TxTienda.pagoSeguroPlay,
              style: TextStyle(fontSize: 13, color: CnsColores.slate(.85)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _referido(ReferralPayload r) {
    return Container(
      key: const ValueKey('tienda-referido'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CnsRadios.tarjeta),
        border: Border.all(color: CnsColores.violeta.withValues(alpha: .2)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_morado.withValues(alpha: .4), CnsColores.transparente],
        ),
        boxShadow: [BoxShadow(color: _morado.withValues(alpha: .1), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  TxTienda.referidoTitulo.toUpperCase(),
                  style: CnsTipos.cejilla(size: 11, tracking: .1, weight: FontWeight.w700, color: _lilaTenue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 14, height: 1.6, color: CnsColores.slate400),
              children: [
                const TextSpan(text: TxTienda.referidoAntes),
                TextSpan(
                  text: '${r.rewardPerReferral} ✨',
                  style: const TextStyle(color: _amarillo, fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: TxTienda.referidoDespues),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: Colors.black.withValues(alpha: .3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.white.withValues(alpha: .1)),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey('tienda-codigo'),
                  onTap: () => _copiar(r.referralCode),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.referralCode,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontFamilyFallback: ['Courier New', 'Courier'],
                              fontSize: 14,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.bold,
                              color: _lila,
                            ),
                          ),
                        ),
                        Icon(Icons.copy_rounded, size: 16, color: CnsColores.slate(.8)),
                      ],
                    ),
                  ),
                ),
              ),
              if (_copiado)
                Positioned(
                  top: -30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _esmeralda,
                        borderRadius: BorderRadius.circular(CnsRadios.pildora),
                        boxShadow: [BoxShadow(color: _esmeralda.withValues(alpha: .2), blurRadius: 10)],
                      ),
                      child: const Text(
                        TxTienda.copiado,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            TxTienda.tocaCopiar,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: CnsColores.slate(.7)),
          ),
        ],
      ),
    );
  }
}

/// Un paquete en dos pisos, como la web en el teléfono: qué es, y cuánto
/// cuesta.
class _PaqueteCard extends StatelessWidget {
  const _PaqueteCard({required this.offer, required this.buying, required this.onComprar});

  final _Offer offer;
  final String? buying;
  final VoidCallback onComprar;

  // El color va con el icono, como en la web.
  (Widget, Color) get _icono => switch (offer.package.icon) {
        'star' => (const Icon(Icons.star_rounded, size: 28, color: CnsColores.violeta), CnsColores.violeta),
        'globe-alt' => (const Icon(Icons.public_rounded, size: 28, color: _ambar), _ambar),
        _ => (const Text('✦', style: TextStyle(fontSize: 26, height: 1, color: CnsColores.cian)), CnsColores.cian),
      };

  @override
  Widget build(BuildContext context) {
    final package = offer.package;
    final destacado = package.highlight;
    final (icono, color) = _icono;

    return Container(
      key: ValueKey('paquete-${package.productId}'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CnsRadios.tarjeta),
        border: Border.all(color: destacado ? _ambar : CnsColores.slate(.16), width: destacado ? 1.4 : 1),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [CnsColores.tarjetaA, CnsColores.tarjetaB],
        ),
        boxShadow: destacado
            ? [BoxShadow(color: _ambar.withValues(alpha: .2), blurRadius: 22, offset: const Offset(0, 8))]
            : const [BoxShadow(color: CnsColores.sombra, blurRadius: 12, offset: Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: icono,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            // Que el nombre no quede bajo la cinta.
                            padding: EdgeInsets.only(right: destacado ? 72 : 0),
                            child: Text(
                              package.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: CnsColores.titulo),
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (r) => const LinearGradient(
                                  colors: [Color(0xFFA855F7), Color(0xFF06B6D4)],
                                ).createShader(r),
                                child: Text(
                                  '${package.coins}',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  TxTienda.polvoEstelar,
                                  style: TextStyle(fontWeight: FontWeight.w600, color: CnsColores.slate(.9)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (package.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    package.description,
                    style: TextStyle(fontSize: 13, height: 1.5, color: CnsColores.slate(.8)),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: CnsColores.slate(.14)))),
                  child: Row(
                    children: [
                      // El de la tienda, en la moneda del usuario; nunca price_clp.
                      Expanded(
                        child: Text(
                          offer.product.price,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: CnsColores.textoFuerte),
                        ),
                      ),
                      _BotonComprar(
                        destacado: destacado,
                        procesando: buying == package.productId,
                        onTap: buying == null ? onComprar : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (destacado)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: const BoxDecoration(
                  color: _ambar,
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8)),
                ),
                child: const Text(
                  TxTienda.mejorValor,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lleno en el destacado y con borde en los demás, como `primary`/`outline`.
class _BotonComprar extends StatelessWidget {
  const _BotonComprar({required this.destacado, required this.procesando, required this.onTap});

  final bool destacado;
  final bool procesando;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final texto = destacado ? const Color(0xFF1C1917) : CnsColores.texto;
    final hijo = procesando
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: texto)),
              const SizedBox(width: 8),
              const Text(TxTienda.procesando),
            ],
          )
        : const Text(TxTienda.comprarAhora);
    final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(CnsRadios.casilla));
    const relleno = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    const letra = TextStyle(fontWeight: FontWeight.bold, fontSize: 14);

    return destacado
        ? FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: _ambar,
              foregroundColor: texto,
              disabledBackgroundColor: _ambar.withValues(alpha: procesando ? .85 : .35),
              disabledForegroundColor: texto.withValues(alpha: procesando ? 1 : .6),
              shape: forma,
              padding: relleno,
              textStyle: letra,
            ),
            child: hijo,
          )
        : OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: texto,
              disabledForegroundColor: texto.withValues(alpha: procesando ? 1 : .45),
              side: BorderSide(color: CnsColores.slate(.3)),
              shape: forma,
              padding: relleno,
              textStyle: letra,
            ),
            child: hijo,
          );
  }
}

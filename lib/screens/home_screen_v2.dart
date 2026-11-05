import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/ads_config.dart';
import '../config/app_config.dart';
import '../models/aviso.dart';
import '../services/alerts_service.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../services/push_service.dart';
import '../widgets/wallpaper_sheet.dart';
import 'alerts_screen.dart';
import 'observatorio_tab.dart';
import 'landscapes_screen.dart';
import 'oracle_consultations_screen.dart';
import 'profile_screen.dart'; // Importar perfil
import 'user_map_tab.dart';

// Colores celestiales (WindowsDemeter)
const backgroundColor = Color(0xFF0A0A0F);
const accentCyan = Color(0xFF4FD0E7);
const accentPurple = Color(0xFF8B5CF6);
const cardBackground = Color(0xEF0F172A);
const textColor = Color(0xFFF7FAFC);
const secondaryTextColor = Color(0xFF94A3B8);

class HomeScreenV2 extends StatefulWidget {
  const HomeScreenV2({super.key});

  @override
  State<HomeScreenV2> createState() => _HomeScreenV2State();
}

class _HomeScreenV2State extends State<HomeScreenV2>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();

  // DEMETER (el mapa), CONSULTAS y OBSERVATORIO. Las alertas están en el menú
  // de la cuenta.
  late final TabController _tabs = TabController(length: 3, vsync: this)
    ..addListener(_onTabChanged);
  bool _mapActive = true;

  final PushService _push = PushService.instance;
  StreamSubscription<Aviso>? _received;

  // AdMob banner
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdsConfig.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('Failed to load a banner ad: ${err.message}');
          _isBannerAdReady = false;
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBannerAd();

    // Con sesión: el teléfono se registra para el push y, la primera vez, se
    // pide el permiso para que los avisos lleguen como notificaciones. Un
    // aviso que llega o se toca se refleja aquí.
    unawaited(_push.register().then((_) => _push.askPermissionOnce()));
    unawaited(_refreshUnreadAlerts());
    // Compras de Play que el servidor todavía no confirmó.
    unawaited(BillingService.instance.recover());
    _received = _push.received.listen((_) => _refreshUnreadAlerts());
    _push.openedAviso.addListener(_openTappedAviso);
    // La app pudo abrirse tocando una notificación.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openTappedAviso());
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _received?.cancel();
    _push.openedAviso.removeListener(_openTappedAviso);
    WidgetsBinding.instance.removeObserver(this);
    _tabs.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pudo llegar un aviso con la app en segundo plano, o pagarse una compra
    // pendiente. El mapa se cuida solo (MapWebView).
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshUnreadAlerts());
      unawaited(BillingService.instance.recover());
    }
  }

  /// El WebView del mapa solo está en pantalla con su pestaña a la vista.
  void _onTabChanged() {
    final map = _tabs.index == 0;
    if (map != _mapActive) setState(() => _mapActive = map);
  }

  /// El número de avisos sin leer del menú de la cuenta. Nunca lanza.
  Future<void> _refreshUnreadAlerts() async {
    try {
      await AlertsService().list();
    } catch (e) {
      debugPrint('Sin la cuenta de avisos (${e.runtimeType}).');
    }
  }

  /// Abre Alertas con el aviso de la notificación que tocó el usuario, que
  /// se marca leído.
  void _openTappedAviso() {
    final aviso = _push.openedAviso.value;
    if (aviso == null || !mounted) return;
    _push.openedAviso.value = null;
    _openAlerts(opened: aviso);
  }

  void _openAlerts({Aviso? opened}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AlertsScreen(opened: opened, onCreateFavorite: _goCreateFavorite),
    ));
  }

  /// Sin favoritos no llegan avisos: al mapa, donde se guarda «Mi ubicación».
  void _goCreateFavorite() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _tabs.animateTo(0);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Toca ☆ junto al lugar para guardarlo en tus favoritos.'),
      ));
  }

  /// Espacio fijo del banner bajo el mapa: si apareciera después, el mapa
  /// cambiaría de alto y se recargaría.
  Widget _bannerSlot() {
    final ad = _bannerAd;
    return SizedBox(
      height: AdSize.banner.height.toDouble(),
      child: _isBannerAdReady && ad != null
          ? Center(
              child: SizedBox(
                width: ad.size.width.toDouble(),
                height: ad.size.height.toDouble(),
                child: AdWidget(ad: ad),
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: PopupMenuButton<String>(
          // Con avisos sin leer, un punto, como la campana 🔔 de la web.
          icon: ValueListenableBuilder<int?>(
            valueListenable: unreadAlerts,
            builder: (context, unread, _) => Badge(
              isLabelVisible: unread != null && unread > 0,
              smallSize: 8,
              backgroundColor: _unreadColor,
              child: const Icon(
                Icons.account_circle_outlined,
                size: 24,
                color: secondaryTextColor,
              ),
            ),
          ),
          tooltip: "Usuario",
          offset: const Offset(0, 40),
          color: cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: accentCyan.withValues(alpha: 0.2)),
          ),
          onSelected: (value) async {
            if (value == 'profile') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            } else if (value == 'alerts') {
              _openAlerts();
            } else if (value == 'landscapes') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LandscapesScreen()),
              );
            } else if (value == 'logout') {
              await _authService.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, kGuestRoute, (_) => false);
              }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline, color: accentCyan, size: 20),
                  SizedBox(width: 10),
                  Text("Ver Perfil", style: TextStyle(color: textColor)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'alerts',
              child: _AlertsMenuLabel(),
            ),
            const PopupMenuItem(
              value: 'landscapes',
              child: Row(
                children: [
                  Icon(Icons.landscape_outlined, color: accentCyan, size: 20),
                  SizedBox(width: 10),
                  Text("Mis paisajes", style: TextStyle(color: textColor)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                  SizedBox(width: 10),
                  Text("Cerrar Sesión", style: TextStyle(color: textColor)),
                ],
              ),
            ),
          ],
        ),
        title: Container(
          height: 38,
          decoration: BoxDecoration(
            color: cardBackground.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentCyan.withValues(alpha: 0.1)),
          ),
          child: TabBar(
            controller: _tabs,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: accentCyan.withValues(alpha: 0.1),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: accentCyan,
            unselectedLabelColor: secondaryTextColor,
            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 9.5,
              letterSpacing: 0.5,
            ),
            tabs: const [
              Tab(text: "DEMETER"),
              Tab(text: "CONSULTAS"),
              Tab(text: "OBSERVATORIO"),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          // El fondo animado solo existe en Android.
          if (Platform.isAndroid)
            IconButton(
              icon: const Icon(
                Icons.wallpaper_rounded,
                size: 20,
                color: accentCyan,
              ),
              tooltip: "Fondo animado",
              onPressed: () => showWallpaperSheet(
                context,
                onCreateFavorite: _goCreateFavorite,
              ),
            )
          else
            const SizedBox(width: 48), // Espacio simétrico
        ],
      ),
      // El AppBar ya cubre la barra de estado; esto cuida la de navegación.
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tabs,
          physics: const NeverScrollableScrollPhysics(), // Evita conflicto con gestos
          children: [
            UserMapTab(active: _mapActive, footer: _bannerSlot()),
            const OracleConsultationsScreen(),
            const ObservatorioTab(),
          ],
        ),
      ),
    );
  }
}

const _unreadColor = Color(0xFFF59E0B);

/// «Alertas» en el menú de la cuenta, con los avisos sin leer.
class _AlertsMenuLabel extends StatelessWidget {
  const _AlertsMenuLabel();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: unreadAlerts,
      builder: (context, unread, _) => Row(
        children: [
          const Icon(Icons.notifications_outlined, color: accentCyan, size: 20),
          const SizedBox(width: 10),
          const Text("Alertas", style: TextStyle(color: textColor)),
          if (unread != null && unread > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _unreadColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                unread > 9 ? "9+" : "$unread",
                style: const TextStyle(
                  color: backgroundColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

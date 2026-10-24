import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/ads_config.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/live_wallpaper_service.dart';
import '../services/location_service.dart';
import 'astral_charts_screen.dart';
import 'landscapes_screen.dart';
import 'oracle_consultations_screen.dart';
import 'profile_screen.dart'; // Importar perfil
import 'user_map_tab.dart';
import '../services/wallpaper_refresh_service.dart';

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

  // MAPA, CONSULTAS, CARTAS y ALERTAS.
  late final TabController _tabs = TabController(length: 4, vsync: this)
    ..addListener(_onTabChanged);
  bool _mapActive = true;

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
    // Abrir la app es una acción explícita: el fondo se refresca sin esperar
    // el intervalo.
    _updateWallpaperIfNeeded(force: true);
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _tabs.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Volver de background no es una acción explícita del usuario, así que
    // acá sí respetamos el intervalo mínimo entre refrescos del fondo. El
    // mapa se cuida solo (MapWebView).
    if (state == AppLifecycleState.resumed) _updateWallpaperIfNeeded();
  }

  /// El WebView del mapa solo está en pantalla con su pestaña a la vista.
  void _onTabChanged() {
    final active = _tabs.index == 0;
    if (active != _mapActive) setState(() => _mapActive = active);
  }

  /// Refresca el fondo del sistema si el usuario lo habilitó.
  ///
  /// Con [force] en `false` (retorno desde background) se respeta
  /// [kWallpaperRefreshInterval] para no regenerar el PNG en cada cambio de
  /// app. Con `true` (abrir la app) se actualiza siempre.
  ///
  /// Nunca lanza: es un refresco de fondo y no debe interrumpir la pantalla.
  /// Los errores quedan en el log del canal `wallpaper`.
  Future<void> _updateWallpaperIfNeeded({bool force = false}) async {
    if (!Platform.isAndroid) return;

    try {
      // Respetar la preferencia del usuario: si no activó el auto-refresh, no
      // tocamos su fondo de pantalla.
      if (!await isWallpaperAutoRefreshEnabled()) {
        if (kDebugMode) {
          debugPrint('Wallpaper auto-refresh desactivado por el usuario');
        }
        return;
      }

      // Sin configuración guardada el usuario nunca aplicó un fondo.
      if (!await hasWallpaperConfig()) {
        if (kDebugMode) debugPrint('No hay configuración de wallpaper guardada');
        return;
      }

      if (!force) {
        final lastRefresh = await lastWallpaperRefresh();
        if (lastRefresh != null) {
          final elapsed = DateTime.now().difference(lastRefresh);
          if (elapsed < kWallpaperRefreshInterval) {
            if (kDebugMode) {
              debugPrint(
                'Wallpaper actualizado hace ${elapsed.inMinutes} min, esperando...',
              );
            }
            return;
          }
        }
      }

      // El fondo sigue a la ubicación actual si ya hay permiso (sin pedirlo).
      final location = await LocationService.instance.current();
      if (location != null) {
        await persistWallpaperCoordinates(lat: location.lat, lon: location.lon);
      }

      if (!mounted) return;
      await refreshWallpaperFromServer(
        date: DateTime.now(),
        screenSize: _physicalScreenSize(),
      );
      if (kDebugMode) debugPrint('Wallpaper del sistema actualizado ✓');
    } catch (e) {
      if (kDebugMode) debugPrint('Error actualizando wallpaper: $e');
    }
  }

  /// Tamaño en píxeles físicos de la pantalla, para rasterizar el fondo a
  /// resolución nativa.
  ui.Size? _physicalScreenSize() {
    if (!mounted) return null;
    return View.maybeOf(context)?.physicalSize;
  }

  /// La ubicación actual si hay permiso; si no, la última guardada o la de
  /// por defecto. Ya viene redondeada a 2 decimales.
  Future<({double lat, double lon})> _wallpaperCoordinates() async {
    final location = await LocationService.instance.current();
    if (location != null) return (lat: location.lat, lon: location.lon);
    final prefs = await SharedPreferences.getInstance();
    return (
      lat: prefs.getDouble(kWallpaperLatKey) ?? kDefaultLatitude,
      lon: prefs.getDouble(kWallpaperLonKey) ?? kDefaultLongitude,
    );
  }

  Future<void> _showWallpaperOptions(BuildContext ctx) async {
    // Estado actual de la preferencia, para que el switch abra en su valor real.
    var autoRefresh = await isWallpaperAutoRefreshEnabled();
    final configured = await hasWallpaperConfig();
    if (!ctx.mounted) return;

    await showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Fondo de Pantalla Celestial",
                    style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "El cielo se obtiene en tiempo real desde el servidor.",
                    style: TextStyle(color: secondaryTextColor, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.home_outlined, color: accentCyan),
                    title: const Text("Pantalla Principal", style: TextStyle(color: textColor)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _applyWallpaper(ctx, WallpaperTarget.home);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: accentCyan),
                    title: const Text("Pantalla de Bloqueo", style: TextStyle(color: textColor)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _applyWallpaper(ctx, WallpaperTarget.lock);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.wallpaper_rounded, color: accentPurple),
                    title: const Text("Ambas Pantallas",
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _applyWallpaper(ctx, WallpaperTarget.both);
                    },
                  ),
                  const Divider(color: Colors.white12),
                  ListTile(
                    leading: const Icon(Icons.animation_rounded, color: accentPurple),
                    title: const Text("Fondo Animado", style: TextStyle(color: textColor)),
                    subtitle: const Text(
                      "Activa el cielo en vivo desde los ajustes de Android",
                      style: TextStyle(color: secondaryTextColor, fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _openLiveWallpaperPicker(ctx);
                    },
                  ),
                  const Divider(color: Colors.white12),
                  // Opt-in explícito: sin esto la app nunca cambia el fondo por
                  // su cuenta, solo cuando el usuario lo pide desde acá.
                  SwitchListTile(
                    value: autoRefresh,
                    activeThumbColor: accentCyan,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Actualizar automáticamente",
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                    subtitle: Text(
                      configured
                          ? "Al abrir la app y al volver a ella."
                          : "Aplica primero un fondo para poder activarlo.",
                      style: const TextStyle(color: secondaryTextColor, fontSize: 11),
                    ),
                    onChanged: configured
                        ? (value) async {
                            await setWallpaperAutoRefreshEnabled(value);
                            autoRefresh = value;
                            setSheetState(() {});
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openLiveWallpaperPicker(BuildContext ctx) async {
    final opened = await LiveWallpaperService.openPicker();
    if (!ctx.mounted || opened) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(
        content: Text(
          "Tu dispositivo no permite abrir el selector de fondos animados.",
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _applyWallpaper(BuildContext ctx, WallpaperTarget target) async {
    if (!Platform.isAndroid) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text("Fondo de pantalla solo disponible en Android."),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final screenSize = _physicalScreenSize();
    final messenger = ScaffoldMessenger.of(ctx);
    messenger.showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 12),
          Text("Generando fondo celestial..."),
        ]),
        duration: Duration(seconds: 60),
        backgroundColor: accentPurple,
      ),
    );

    try {
      final coords = await _wallpaperCoordinates();
      await persistWallpaperSettings(lat: coords.lat, lon: coords.lon, target: target);

      // El destino va explícito: antes se forzaba 'both' y se ignoraba lo que
      // el usuario había elegido en la hoja de opciones.
      await refreshWallpaperFromServer(
        date: DateTime.now(),
        target: target,
        screenSize: screenSize,
      );
      if (!ctx.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text("¡Fondo celestial aplicado en ${_targetLabel(target)}! ✨"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } on WallpaperRefreshException catch (e) {
      if (!ctx.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!ctx.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text("No se pudo aplicar el fondo: $e"),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  String _targetLabel(WallpaperTarget target) => switch (target) {
        WallpaperTarget.home => "la pantalla principal",
        WallpaperTarget.lock => "la pantalla de bloqueo",
        WallpaperTarget.both => "ambas pantallas",
      };

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
          icon: const Icon(
            Icons.account_circle_outlined,
            size: 24,
            color: secondaryTextColor,
          ),
          tooltip: "Usuario",
          offset: const Offset(0, 40),
          color: cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: accentCyan.withOpacity(0.2)),
          ),
          onSelected: (value) async {
            if (value == 'profile') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
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
            color: cardBackground.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentCyan.withOpacity(0.1)),
          ),
          child: TabBar(
            controller: _tabs,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: accentCyan.withOpacity(0.1),
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
              Tab(text: "MAPA"),
              Tab(text: "CONSULTAS"),
              Tab(text: "CARTAS"),
              Tab(text: "ALERTAS"),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          // El fondo de pantalla solo existe en Android.
          if (Platform.isAndroid)
            IconButton(
              icon: const Icon(
                Icons.wallpaper_rounded,
                size: 20,
                color: accentCyan,
              ),
              tooltip: "Fondo de Pantalla Celestial",
              onPressed: () => _showWallpaperOptions(context),
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
            const AstralChartsScreen(),
            const _AlertsTab(),
          ],
        ),
      ),
    );
  }
}

/// Las alertas llegan en la fase 4: clima, catástrofes y avisos astrológicos.
class _AlertsTab extends StatelessWidget {
  const _AlertsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded, color: secondaryTextColor, size: 48),
            SizedBox(height: 16),
            Text(
              "Alertas",
              style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Muy pronto: alertas climáticas, catástrofes en curso y avisos "
              "astrológicos para tus lugares favoritos.",
              textAlign: TextAlign.center,
              style: TextStyle(color: secondaryTextColor, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

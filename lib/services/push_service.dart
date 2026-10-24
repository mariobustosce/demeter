import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/aviso.dart';
import 'api_client.dart';
import 'token_store.dart';

/// Canal de Android de los avisos. Si el servidor cambia
/// `APP_PUSH_CANAL_ANDROID`, hay que cambiarlo aquí y en el manifest.
const String kAlertsChannelId = 'alertas';
const String _channelName = 'Alertas';
const String _channelDescription =
    'Clima, catástrofes y avisos astrológicos de tus lugares favoritos.';

// El icono va también en el manifest (el de los push que muestra Android) y
// por eso R8 no lo borra.
const String _icon = 'ic_notificacion';
const Color _color = Color(0xFF4FD0E7);

/// Notificaciones push de los avisos, con FCM.
///
/// - El teléfono se registra en el servidor al abrir la app con sesión y
///   cuando FCM cambia el token; se borra al cerrar sesión.
/// - Con la app abierta, Android no muestra el push: lo arma la app con el
///   canal `alertas` y visibilidad privada.
/// - Al tocar una notificación, el aviso queda en [openedAviso] y lo abre la
///   pantalla principal, que solo existe con sesión.
///
/// iOS (pendiente): tras `flutterfire configure`, subir la clave APNs (.p8) a
/// Firebase → Cloud Messaging y activar en Xcode «Push Notifications» y
/// «Background Modes → Remote notifications». Sin eso no llega nada.
class PushService {
  PushService({
    ApiClient? api,
    TokenStore? session,
    bool? available,
    Future<String?> Function()? getToken,
    Future<void> Function()? deleteToken,
    Future<bool> Function()? requestPermission,
    Future<bool> Function()? hasPermission,
  })  : _apiOverride = api,
        _session = session ?? TokenStore(),
        _availableOverride = available,
        _getToken = getToken,
        _deleteToken = deleteToken,
        _requestPermission = requestPermission,
        _hasPermission = hasPermission;

  /// Instancia que usa la app. Los tests pueden reemplazarla.
  static PushService instance = PushService();

  final ApiClient? _apiOverride;
  ApiClient get _api => _apiOverride ?? ApiClient.instance;
  final TokenStore _session;
  final bool? _availableOverride;
  final Future<String?> Function()? _getToken;
  final Future<void> Function()? _deleteToken;
  final Future<bool> Function()? _requestPermission;
  final Future<bool> Function()? _hasPermission;

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final StreamController<Aviso> _received = StreamController<Aviso>.broadcast();
  bool _started = false;

  // El último token que aceptó el servidor: es el que se borra al salir.
  String? _registeredToken;

  /// El aviso que el usuario abrió desde una notificación, hasta que la
  /// pantalla principal lo muestre y lo vuelva a `null`.
  final ValueNotifier<Aviso?> openedAviso = ValueNotifier<Aviso?>(null);

  /// Avisos que llegan con la app abierta: la lista y el número se refrescan.
  Stream<Aviso> get received => _received.stream;

  /// Sin Firebase (iOS hasta que se configure) no hay push.
  bool get available =>
      _availableOverride ??
      ((Platform.isAndroid || Platform.isIOS) && Firebase.apps.isNotEmpty);

  /// Se llama al arrancar, con Firebase ya listo. No pide permiso.
  Future<void> start() async {
    if (_started || !available) return;
    _started = true;
    await _startLocal();
    try {
      FirebaseMessaging.onMessage.listen(_showInForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_openMessage);
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => unawaited(_send(token)),
      );
      // La app estaba cerrada y se abrió tocando el push del sistema.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _openMessage(initial);
    } catch (e) {
      debugPrint('Push: FCM no arrancó (${e.runtimeType}).');
    }
  }

  /// Las notificaciones que arma la app con ella abierta, y su canal.
  Future<void> _startLocal() async {
    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(_icon),
          // En iOS el permiso se pide al activar la primera alerta, no aquí.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) => _openPayload(response.payload),
      );
      // El canal tiene que existir antes del primer push en segundo plano.
      await _android?.createNotificationChannel(const AndroidNotificationChannel(
        kAlertsChannelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ));
      // La app se cerró con una notificación suya a la vista y se abrió con
      // ella.
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _openPayload(launch?.notificationResponse?.payload);
      }
    } catch (e) {
      debugPrint('Push: las notificaciones locales no arrancaron (${e.runtimeType}).');
    }
  }

  /// Registra el teléfono para los avisos de esta cuenta. Nunca lanza.
  Future<void> register() async {
    if (!available) return;
    try {
      final token = await (_getToken ?? FirebaseMessaging.instance.getToken)();
      if (token != null) await _send(token);
    } catch (e) {
      debugPrint('Push: no se registró el teléfono (${e.runtimeType}).');
    }
  }

  Future<void> _send(String token) async {
    // Sin sesión no hay a quién avisar (FCM puede cambiar el token igual).
    if (await _session.read() == null) return;
    try {
      await _api.post('/dispositivos', body: {
        'fcm_token': token,
        'plataforma': Platform.isIOS ? 'ios' : 'android',
        'version_app': ?await _appVersion(),
      });
      _registeredToken = token;
    } catch (e) {
      debugPrint('Push: el servidor no registró el teléfono (${e.runtimeType}).');
    }
  }

  /// Al cerrar sesión, con el token de la app todavía vivo: el servidor deja
  /// de mandar avisos a este teléfono.
  Future<void> unregister() async {
    final token = _registeredToken;
    if (token == null) return;
    await _api.delete('/dispositivos', body: {'fcm_token': token});
    _registeredToken = null;
  }

  /// Borra lo del push en el teléfono: el token de FCM (el próximo usuario
  /// tendrá otro) y las notificaciones a la vista, que pueden nombrar sus
  /// lugares. También tras un 401. Nunca lanza.
  Future<void> forget() async {
    openedAviso.value = null;
    _registeredToken = null;
    if (!available) return;
    try {
      await _local.cancelAll();
    } catch (e) {
      debugPrint('Push: no se quitaron las notificaciones (${e.runtimeType}).');
    }
    try {
      await (_deleteToken ?? FirebaseMessaging.instance.deleteToken)();
    } catch (e) {
      debugPrint('Push: no se borró el token (${e.runtimeType}).');
    }
  }

  /// Pide permiso para notificar (Android 13+ e iOS). Va al activar una
  /// alerta, nunca al abrir la app. `true` si quedó concedido.
  Future<bool> requestPermission() async {
    if (!available) return false;
    try {
      if (_requestPermission != null) return await _requestPermission();
      final settings = await FirebaseMessaging.instance.requestPermission();
      return _allowed(settings);
    } catch (e) {
      debugPrint('Push: no se pudo pedir permiso (${e.runtimeType}).');
      return false;
    }
  }

  /// Si el teléfono deja mostrar los avisos, sin preguntar nada.
  Future<bool> hasPermission() async {
    if (!available) return false;
    try {
      if (_hasPermission != null) return await _hasPermission();
      return _allowed(await FirebaseMessaging.instance.getNotificationSettings());
    } catch (e) {
      return false;
    }
  }

  /// Si Android ya no muestra el diálogo (lo negó dos veces), los ajustes de
  /// notificaciones de la app. `false` si no se pudieron abrir.
  Future<bool> openSettings() async {
    try {
      return await _android?.openAppNotificationSettings() ?? false;
    } catch (e) {
      return false;
    }
  }

  static bool _allowed(NotificationSettings settings) =>
      settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Con la app abierta: la notificación se arma con `data`, como el push.
  Future<void> _showInForeground(RemoteMessage message) async {
    final aviso = Aviso.fromPush(message.data);
    if (aviso == null) return;
    _received.add(aviso);
    try {
      await _local.show(
        id: aviso.id.hashCode,
        title: aviso.title,
        body: aviso.text,
        payload: jsonEncode(pushPayload(aviso)),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            kAlertsChannelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            // Si el usuario oculta lo sensible en la pantalla de bloqueo, no
            // se ve el lugar.
            visibility: NotificationVisibility.private,
            icon: _icon,
            color: _color,
            styleInformation: BigTextStyleInformation(aviso.text),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Push: no se mostró el aviso (${e.runtimeType}).');
    }
  }

  void _openMessage(RemoteMessage message) => open(message.data);

  void _openPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload);
      if (data is Map<String, dynamic>) open(data);
    } on FormatException {
      return;
    }
  }

  /// Deja en [openedAviso] el aviso de un push, si lo es.
  @visibleForTesting
  void open(Map<String, dynamic> data) {
    final aviso = Aviso.fromPush(data);
    if (aviso != null) openedAviso.value = aviso;
  }

  /// El `data` del push, para la notificación que arma la app.
  @visibleForTesting
  static Map<String, String> pushPayload(Aviso aviso) => {
        'aviso_id': aviso.id,
        'tipo': aviso.type,
        'titulo': aviso.title,
        'texto': aviso.text,
      };

  /// `1.0.6+10`, con el tope de 20 caracteres del servidor.
  static Future<String?> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = '${info.version}+${info.buildNumber}';
      return version.length > 20 ? version.substring(0, 20) : version;
    } catch (_) {
      return null;
    }
  }
}

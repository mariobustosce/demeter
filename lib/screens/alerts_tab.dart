import 'dart:async';

import 'package:flutter/material.dart';

import '../models/aviso.dart';
import '../services/alerts_service.dart';
import '../services/api_client.dart';
import '../services/push_service.dart';
import 'avisos_screen.dart';

const _cardBackground = Color(0xFF0F172A);
const _accentCyan = Color(0xFF4FD0E7);
const _amber = Color(0xFFF59E0B);
const _violet = Color(0xFFA78BFA);
const _textColor = Color(0xFFF7FAFC);
const _secondaryTextColor = Color(0xFF94A3B8);

/// Pestaña ALERTAS: qué avisos quiere el usuario, en las tres secciones de la
/// web, y la entrada a los que le llegaron.
class AlertsTab extends StatefulWidget {
  const AlertsTab({
    super.key,
    required this.active,
    required this.onCreateFavorite,
    this.alerts,
    this.push,
  });

  /// Al volver a la pestaña se recargan: el usuario pudo crear un favorito o
  /// cambiar algo en la web.
  final bool active;

  /// Sin favoritos no llega ningún aviso: lleva a guardar uno en el mapa.
  final VoidCallback onCreateFavorite;

  final AlertsService? alerts;
  final PushService? push;

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> with WidgetsBindingObserver {
  late final AlertsService _alerts = widget.alerts ?? AlertsService();
  PushService get _push => widget.push ?? PushService.instance;

  AlertPreferences? _prefs;
  String? _error;
  final Set<String> _saving = {};

  // Hasta saberlo se supone que sí, para no mostrar el aviso de más.
  bool _notificationsAllowed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didUpdateWidget(AlertsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pudo volver de los ajustes de notificaciones de Android.
    if (state == AppLifecycleState.resumed && widget.active) _checkPermission();
  }

  Future<void> _load() async {
    unawaited(_checkPermission());
    unawaited(_refreshUnread());
    try {
      final prefs = await _alerts.preferences();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _error = null;
      });
    } on UnauthorizedException {
      return; // El ApiClient ya llevó al mapa de invitado.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('Alertas: no se cargaron (${e.runtimeType}).');
      if (mounted) setState(() => _error = 'No se pudieron cargar las alertas.');
    }
  }

  Future<void> _refreshUnread() async {
    try {
      await _alerts.list();
    } catch (e) {
      debugPrint('Alertas: sin la cuenta de avisos (${e.runtimeType}).');
    }
  }

  Future<void> _checkPermission() async {
    if (!_push.available) return;
    final allowed = await _push.hasPermission();
    if (mounted && allowed != _notificationsAllowed) {
      setState(() => _notificationsAllowed = allowed);
    }
  }

  Future<void> _toggle(AlertType alert, bool active) async {
    final prefs = _prefs;
    if (prefs == null || _saving.contains(alert.type)) return;
    setState(() {
      _saving.add(alert.type);
      _prefs = prefs.withActive(alert.type, active);
    });
    try {
      final saved = await _alerts.setActive(alert.type, active);
      if (!mounted) return;
      setState(() => _prefs = saved);
    } on UnauthorizedException {
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _prefs = _prefs?.withActive(alert.type, !active));
      _notify(e is ApiException ? e.message : 'No se pudo guardar.');
      return;
    } finally {
      if (mounted) setState(() => _saving.remove(alert.type));
    }

    // En contexto: el permiso se pide al activar una alerta, no al abrir la
    // app. Con él ya concedido, Android no pregunta nada.
    if (active && _push.available && !_notificationsAllowed) {
      final allowed = await _push.requestPermission();
      if (mounted) setState(() => _notificationsAllowed = allowed);
    }
  }

  Future<void> _enableNotifications() async {
    var allowed = await _push.requestPermission();
    // Si lo negó dos veces Android ya no pregunta: quedan los ajustes.
    if (!allowed && await _push.openSettings()) return;
    allowed = allowed || await _push.hasPermission();
    if (!mounted) return;
    setState(() => _notificationsAllowed = allowed);
    if (!allowed) {
      _notify('Actívalas en los ajustes del teléfono: Apps → WindowsDemeter → Notificaciones.');
    }
  }

  void _openInbox() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AvisosScreen(
        alerts: _alerts,
        catastropheTypes: _prefs?.catastropheTypes ?? kCatastropheTypes,
      ),
    ));
  }

  void _notify(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    if (prefs == null) {
      final error = _error;
      return error == null
          ? const Center(child: CircularProgressIndicator(color: _accentCyan))
          : _RetryView(message: error, onRetry: _load);
    }

    final sections = prefs.sections;
    return DefaultTabController(
      length: sections.length,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: _InboxButton(onTap: _openInbox),
          ),
          if (!prefs.hasFavorites)
            _Callout(
              icon: Icons.star_rounded,
              color: _amber,
              text: 'Los avisos llegan sobre tus lugares favoritos, así que '
                  'necesitas al menos uno.',
              action: 'Guardar un favorito',
              onAction: widget.onCreateFavorite,
            ),
          if (_push.available && prefs.anyActive && !_notificationsAllowed)
            _Callout(
              icon: Icons.notifications_off_outlined,
              color: _accentCyan,
              text: 'Las notificaciones de la app están apagadas: los avisos '
                  'solo se verán aquí.',
              action: 'Activarlas',
              onAction: _enableNotifications,
            ),
          if (sections.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'No hay alertas disponibles.',
                  style: TextStyle(color: _secondaryTextColor),
                ),
              ),
            )
          else ...[
            TabBar(
              dividerColor: Colors.white12,
              indicatorColor: _accentCyan,
              labelColor: _accentCyan,
              unselectedLabelColor: _secondaryTextColor,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              tabs: [for (final s in sections) _SectionTab(section: s)],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final s in sections)
                    _SectionPanel(section: s, saving: _saving, onChanged: _toggle),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// El color y el icono de cada sección, los de la web.
({Color color, IconData icon}) _look(String key) => switch (key) {
      'catastrofes' => (color: _amber, icon: Icons.warning_amber_rounded),
      'astrologicos' => (color: _violet, icon: Icons.nightlight_outlined),
      _ => (color: _accentCyan, icon: Icons.cloud_outlined),
    };

class _SectionTab extends StatelessWidget {
  const _SectionTab({required this.section});

  final AlertSection section;

  @override
  Widget build(BuildContext context) {
    final look = _look(section.key);
    final count = section.activeCount;
    return Tab(
      height: 62,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(look.icon, size: 18, color: look.color),
              if (count > 0) ...[
                const SizedBox(width: 4),
                _CountPill(count: count, color: look.color),
              ],
            ],
          ),
          const SizedBox(height: 3),
          // Los nombres de la web, en dos líneas si no caben.
          Text(
            section.title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.15),
          ),
        ],
      ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.section,
    required this.saving,
    required this.onChanged,
  });

  final AlertSection section;
  final Set<String> saving;
  final void Function(AlertType alert, bool active) onChanged;

  @override
  Widget build(BuildContext context) {
    final look = _look(section.key);
    // El texto del servidor ya trae el aviso legal de GDACS; si algún día no
    // lo trae, va el de la app.
    final disclaimer = section.isCatastrophes && !section.text.contains('autoridades');
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: look.color.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: look.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(look.icon, color: look.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: const TextStyle(
                        color: _textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (section.text.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        section.text,
                        style: const TextStyle(color: _secondaryTextColor, fontSize: 13, height: 1.35),
                      ),
                    ],
                    if (disclaimer) ...[
                      const SizedBox(height: 6),
                      const Text(
                        kGdacsDisclaimer,
                        style: TextStyle(color: _amber, fontSize: 12.5, height: 1.3),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (section.alerts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Todavía no hay alertas en esta sección.',
              style: TextStyle(color: _secondaryTextColor, fontSize: 13),
            ),
          ),
        for (final alert in section.alerts)
          SwitchListTile(
            value: alert.active,
            onChanged: saving.contains(alert.type) ? null : (v) => onChanged(alert, v),
            activeThumbColor: look.color,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(
              alert.label,
              style: const TextStyle(color: _textColor, fontSize: 15),
            ),
            subtitle: alert.description.isEmpty
                ? null
                : Text(
                    alert.description,
                    style: const TextStyle(color: _secondaryTextColor, fontSize: 12.5),
                  ),
          ),
      ],
    );
  }
}

/// La entrada a los avisos recibidos, con los no leídos.
class _InboxButton extends StatelessWidget {
  const _InboxButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _accentCyan.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: ValueListenableBuilder<int?>(
            valueListenable: unreadAlerts,
            builder: (context, unread, _) => Row(
              children: [
                const Icon(Icons.notifications_rounded, color: _accentCyan, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Avisos recibidos',
                    style: TextStyle(color: _textColor, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                if (unread != null && unread > 0)
                  Text(
                    unread == 1 ? '1 sin leer' : '$unread sin leer',
                    style: const TextStyle(color: _amber, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                const Icon(Icons.chevron_right_rounded, color: _secondaryTextColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.icon,
    required this.color,
    required this.text,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final Color color;
  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text, style: const TextStyle(color: _textColor, fontSize: 13, height: 1.35)),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onAction,
              child: Text(action, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF0A0A0F), fontSize: 10.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _RetryView extends StatelessWidget {
  const _RetryView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: _secondaryTextColor, size: 44),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _secondaryTextColor, fontSize: 14),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: _accentCyan,
                side: const BorderSide(color: _accentCyan),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

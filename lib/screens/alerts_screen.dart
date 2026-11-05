import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/aviso.dart';
import '../services/alerts_service.dart';
import '../services/api_client.dart';
import '../services/push_service.dart';
import '../widgets/aviso_card.dart';

const _background = Color(0xFF0A0A0F);
const _cardBackground = Color(0xFF0F172A);
const _accentCyan = Color(0xFF4FD0E7);
const _amber = Color(0xFFF59E0B);
const _violet = Color(0xFFA78BFA);
const _textColor = Color(0xFFF7FAFC);
const _secondaryTextColor = Color(0xFF94A3B8);

enum _Filter { unread, all }

/// Alertas, desde el menú de la cuenta: arriba los avisos que llegaron (solo
/// los no leídos, hasta que se pida verlos todos) y abajo qué alertas quiere
/// el usuario, en las tres secciones de la web.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({
    super.key,
    required this.onCreateFavorite,
    this.opened,
    this.alerts,
    this.push,
  });

  /// Sin favoritos no llega ningún aviso: lleva a guardar uno en el mapa.
  final VoidCallback onCreateFavorite;

  /// El de una notificación: se marca leído y va primero, destacado. Si ya
  /// venció, se muestra con lo que trajo el push.
  final Aviso? opened;

  final AlertsService? alerts;
  final PushService? push;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> with WidgetsBindingObserver {
  late final AlertsService _alerts = widget.alerts ?? AlertsService();
  PushService get _push => widget.push ?? PushService.instance;
  StreamSubscription<Aviso>? _received;

  AlertPreferences? _prefs;
  String? _prefsError;
  final Set<String> _saving = {};
  int _section = 0;

  List<Aviso>? _avisos;
  String? _avisosError;
  bool _markingAll = false;
  _Filter _filter = _Filter.unread;

  // Los que se leyeron en esta visita siguen en «Sin leer» hasta recargar,
  // para que no desaparezcan al tocarlos.
  final Set<String> _readHere = {};

  // `null`: «Avisos recibidos» se abre solo si hay alguno sin leer.
  bool? _inboxOpen;

  // Hasta saberlo se supone que sí, para no mostrar el aviso de más.
  bool _notificationsAllowed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Un aviso que llega con la pantalla abierta aparece en la lista.
    _received = _push.received.listen((_) => _loadAvisos());
    _start();
  }

  @override
  void dispose() {
    _received?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pudo volver de los ajustes de notificaciones de Android, o llegar un
    // aviso con la app en segundo plano.
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
      _loadAvisos();
    }
  }

  Future<void> _start() async {
    unawaited(_checkPermission());
    unawaited(_loadPrefs());
    final opened = widget.opened;
    if (opened != null) {
      // Antes de la lista, para que llegue ya leído y con la cuenta al día.
      try {
        await _alerts.markRead(opened.id);
      } on UnauthorizedException {
        return; // El ApiClient ya llevó al mapa de invitado.
      } catch (e) {
        debugPrint('Aviso: no se marcó leído (${e.runtimeType}).');
      }
    }
    await _loadAvisos();
  }

  Future<void> _reload() async {
    _readHere.clear();
    await Future.wait([_loadPrefs(), _loadAvisos(), _checkPermission()]);
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await _alerts.preferences();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _prefsError = null;
        if (_section >= prefs.sections.length) _section = 0;
      });
    } on UnauthorizedException {
      return;
    } on ApiException catch (e) {
      if (mounted) setState(() => _prefsError = e.message);
    } catch (e) {
      debugPrint('Alertas: no se cargaron (${e.runtimeType}).');
      if (mounted) setState(() => _prefsError = 'No se pudieron cargar las alertas.');
    }
  }

  Future<void> _loadAvisos() async {
    try {
      final avisos = await _alerts.list();
      if (!mounted) return;
      setState(() {
        _avisos = _withOpenedFirst(avisos);
        _avisosError = null;
      });
    } on UnauthorizedException {
      return;
    } on ApiException catch (e) {
      if (mounted) setState(() => _avisosError = e.message);
    } catch (e) {
      debugPrint('Avisos: no se cargaron (${e.runtimeType}).');
      if (mounted) setState(() => _avisosError = 'No se pudieron cargar los avisos.');
    }
  }

  List<Aviso> _withOpenedFirst(List<Aviso> avisos) {
    final opened = widget.opened;
    if (opened == null) return avisos;
    final listed = avisos.where((a) => a.id == opened.id).firstOrNull;
    return [
      (listed ?? opened).copyWith(read: true),
      for (final a in avisos)
        if (a.id != opened.id) a,
    ];
  }

  Future<void> _checkPermission() async {
    if (!_push.available) return;
    final allowed = await _push.hasPermission();
    if (mounted && allowed != _notificationsAllowed) {
      setState(() => _notificationsAllowed = allowed);
    }
  }

  // ── Avisos recibidos ──────────────────────────────────────────────────

  void _replace(Aviso aviso) {
    _avisos = [
      for (final a in _avisos ?? const <Aviso>[]) a.id == aviso.id ? aviso : a,
    ];
  }

  Future<void> _markRead(Aviso aviso) async {
    if (aviso.read) return;
    setState(() {
      _readHere.add(aviso.id);
      _replace(aviso.copyWith(read: true));
    });
    final unread = unreadAlerts.value;
    if (unread != null && unread > 0) unreadAlerts.value = unread - 1;
    try {
      await _alerts.markRead(aviso.id);
    } on UnauthorizedException {
      return;
    } catch (e) {
      debugPrint('Aviso: no se marcó leído (${e.runtimeType}).');
      if (!mounted) return;
      setState(() => _replace(aviso));
      if (unread != null) unreadAlerts.value = unread;
      _notify('No se pudo marcar como leído.');
    }
  }

  Future<void> _markAllRead() async {
    setState(() => _markingAll = true);
    try {
      await _alerts.markAllRead();
      if (!mounted) return;
      setState(() {
        for (final a in _avisos ?? const <Aviso>[]) {
          if (!a.read) _readHere.add(a.id);
        }
        _avisos = [for (final a in _avisos ?? const <Aviso>[]) a.copyWith(read: true)];
      });
    } on UnauthorizedException {
      return;
    } on ApiException catch (e) {
      _notify(e.message);
    } catch (e) {
      debugPrint('Avisos: no se marcaron leídos (${e.runtimeType}).');
      _notify('No se pudieron marcar como leídos.');
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _openSource(Uri url) async {
    var opened = false;
    try {
      opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) _notify('No se pudo abrir el enlace.');
  }

  // ── Mis alertas ───────────────────────────────────────────────────────

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

    // En contexto: el permiso se pide al activar una alerta. Con él ya
    // concedido, Android no pregunta nada.
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

  void _notify(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _textColor,
        title: const Text('Alertas', style: TextStyle(fontSize: 18)),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    final prefs = _prefs;
    final prefsError = _prefsError;
    // Sin red, el aviso de la notificación se ve igual.
    final opened = widget.opened;
    if (prefs == null && _avisos == null && opened == null) {
      if (prefsError == null || _avisosError == null) {
        return const Center(child: CircularProgressIndicator(color: _accentCyan));
      }
      return _RetryView(message: prefsError, onRetry: _reload);
    }

    return RefreshIndicator(
      color: _accentCyan,
      onRefresh: _reload,
      child: ListView(
        // Para que se pueda tirar hacia abajo aunque la lista sea corta.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
        children: [
          if (prefs != null && !prefs.hasFavorites)
            _Callout(
              icon: Icons.star_rounded,
              color: _amber,
              text: 'Los avisos llegan sobre tus lugares favoritos, así que '
                  'necesitas al menos uno.',
              action: 'Guardar un favorito',
              onAction: widget.onCreateFavorite,
            ),
          if (prefs != null && _push.available && prefs.anyActive && !_notificationsAllowed)
            _Callout(
              icon: Icons.notifications_off_outlined,
              color: _accentCyan,
              text: 'Las notificaciones de la app están apagadas: los avisos '
                  'solo se verán aquí.',
              action: 'Activarlas',
              onAction: _enableNotifications,
            ),
          const SizedBox(height: 10),
          ..._inbox(),
          const SizedBox(height: 26),
          ..._settings(prefs, prefsError),
        ],
      ),
    );
  }

  List<Widget> _inbox() {
    final opened = widget.opened;
    final avisos = _avisos ?? [if (opened != null) opened.copyWith(read: true)];
    final anyUnread = avisos.any((a) => !a.read);
    final open = _inboxOpen ?? (opened != null || anyUnread);
    final shown = _filter == _Filter.all
        ? avisos
        : [
            for (final a in avisos)
              if (!a.read || _readHere.contains(a.id) || a.id == opened?.id) a,
          ];
    final error = _avisosError;

    return [
      _InboxHeader(open: open, onTap: () => setState(() => _inboxOpen = !open)),
      if (open) ...[
        const SizedBox(height: 10),
        Row(
          children: [
            _FilterPill(
              label: 'Sin leer',
              selected: _filter == _Filter.unread,
              onTap: () => setState(() => _filter = _Filter.unread),
            ),
            const SizedBox(width: 8),
            _FilterPill(
              label: 'Todos',
              selected: _filter == _Filter.all,
              onTap: () => setState(() => _filter = _Filter.all),
            ),
            const Spacer(),
            if (anyUnread)
              IconButton(
                tooltip: 'Marcar todos como leídos',
                visualDensity: VisualDensity.compact,
                onPressed: _markingAll ? null : _markAllRead,
                icon: _markingAll
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _accentCyan),
                      )
                    : const Icon(Icons.done_all_rounded, color: _accentCyan),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (error != null)
          _ErrorBanner(message: error, onRetry: _loadAvisos)
        else if (_avisos == null && shown.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: _accentCyan)),
          )
        else if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            child: Text(
              _filter == _Filter.unread && avisos.isNotEmpty
                  ? 'No tienes avisos sin leer.'
                  : 'No tienes avisos vigentes. Cuando llegue uno de las '
                      'alertas que activaste, aparecerá aquí.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _secondaryTextColor, fontSize: 14),
            ),
          ),
        for (final aviso in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AvisoCard(
              aviso: aviso,
              highlighted: aviso.id == opened?.id,
              catastrophe: (_prefs?.catastropheTypes ?? kCatastropheTypes).contains(aviso.type),
              onTap: () => _markRead(aviso),
              onSource: _openSource,
            ),
          ),
      ],
    ];
  }

  List<Widget> _settings(AlertPreferences? prefs, String? error) {
    const title = Padding(
      padding: EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        'MIS ALERTAS',
        style: TextStyle(
          color: _secondaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
    if (prefs == null) {
      return [
        title,
        if (error != null)
          _ErrorBanner(message: error, onRetry: _loadPrefs)
        else
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: _accentCyan)),
          ),
      ];
    }
    final sections = prefs.sections;
    if (sections.isEmpty) {
      return [
        title,
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No hay alertas disponibles.', style: TextStyle(color: _secondaryTextColor)),
        ),
      ];
    }
    final section = sections[_section.clamp(0, sections.length - 1)];
    return [
      title,
      const Padding(
        padding: EdgeInsets.only(left: 4, bottom: 10),
        child: Text(
          'Elige qué avisos quieres recibir en tus lugares favoritos.',
          style: TextStyle(color: _secondaryTextColor, fontSize: 13),
        ),
      ),
      Row(
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _SectionChoice(
                section: sections[i],
                selected: identical(sections[i], section),
                onTap: () => setState(() => _section = i),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 10),
      _SectionPanel(section: section, saving: _saving, onChanged: _toggle),
    ];
  }
}

/// El color y el icono de cada sección, los de la web.
({Color color, IconData icon}) _look(String key) => switch (key) {
      'catastrofes' => (color: _amber, icon: Icons.warning_amber_rounded),
      'astrologicos' => (color: _violet, icon: Icons.nightlight_outlined),
      _ => (color: _accentCyan, icon: Icons.cloud_outlined),
    };

/// «Avisos recibidos», que abre y cierra la lista, con los no leídos.
class _InboxHeader extends StatelessWidget {
  const _InboxHeader({required this.open, required this.onTap});

  final bool open;
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
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
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
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more_rounded, color: _secondaryTextColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _accentCyan.withValues(alpha: 0.14) : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? _accentCyan : Colors.white24),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _accentCyan : _secondaryTextColor,
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Una de las tres secciones, con su icono y su nombre de la web.
class _SectionChoice extends StatelessWidget {
  const _SectionChoice({required this.section, required this.selected, required this.onTap});

  final AlertSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = _look(section.key);
    return Material(
      color: selected ? look.color.withValues(alpha: 0.12) : _cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? look.color.withValues(alpha: 0.7) : Colors.white12,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 66,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(look.icon, size: 20, color: selected ? look.color : _secondaryTextColor),
                const SizedBox(height: 4),
                // Los nombres de la web, en dos líneas si no caben.
                Text(
                  section.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? _textColor : _secondaryTextColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
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
    return Container(
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: look.color.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
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
          const SizedBox(height: 4),
          if (section.alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
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
              contentPadding: EdgeInsets.zero,
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
      margin: const EdgeInsets.only(top: 10),
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: _secondaryTextColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: _secondaryTextColor, fontSize: 13)),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Reintentar', style: TextStyle(color: _accentCyan)),
          ),
        ],
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

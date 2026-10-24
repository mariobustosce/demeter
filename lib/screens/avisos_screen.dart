import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/aviso.dart';
import '../services/alerts_service.dart';
import '../services/api_client.dart';

const _background = Color(0xFF0A0A0F);
const _cardBackground = Color(0xFF0F172A);
const _accentCyan = Color(0xFF4FD0E7);
const _amber = Color(0xFFF59E0B);
const _textColor = Color(0xFFF7FAFC);
const _secondaryTextColor = Color(0xFF94A3B8);
const _bodyColor = Color(0xFFCBD5E1);
const _linkColor = Color(0xFF60A5FA);

/// Los avisos vigentes, del más nuevo al más viejo, como el «Historial de
/// avisos» de la web. Tocar uno nuevo lo marca leído.
class AvisosScreen extends StatefulWidget {
  const AvisosScreen({
    super.key,
    this.opened,
    this.catastropheTypes = kCatastropheTypes,
    this.alerts,
  });

  /// El de una notificación: se marca leído y va primero, destacado. Si ya
  /// venció, se muestra con lo que trajo el push.
  final Aviso? opened;

  /// Los que llevan el aviso legal de GDACS.
  final Set<String> catastropheTypes;

  final AlertsService? alerts;

  @override
  State<AvisosScreen> createState() => _AvisosScreenState();
}

class _AvisosScreenState extends State<AvisosScreen> {
  late final AlertsService _alerts = widget.alerts ?? AlertsService();

  List<Aviso>? _avisos;
  String? _error;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
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
    await _load();
  }

  Future<void> _load() async {
    try {
      final avisos = await _alerts.list();
      if (!mounted) return;
      setState(() {
        _avisos = _withOpenedFirst(avisos);
        _error = null;
      });
    } on UnauthorizedException {
      return;
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('Avisos: no se cargaron (${e.runtimeType}).');
      if (mounted) setState(() => _error = 'No se pudieron cargar los avisos.');
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

  void _replace(Aviso aviso) {
    _avisos = [
      for (final a in _avisos ?? const <Aviso>[]) a.id == aviso.id ? aviso : a,
    ];
  }

  Future<void> _markRead(Aviso aviso) async {
    if (aviso.read) return;
    setState(() => _replace(aviso.copyWith(read: true)));
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

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
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

  @override
  Widget build(BuildContext context) {
    // Sin red, el aviso de la notificación se ve igual.
    final opened = widget.opened;
    final avisos = _avisos ?? [if (opened != null) opened.copyWith(read: true)];
    final anyUnread = avisos.any((a) => !a.read);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _textColor,
        title: const Text('Avisos', style: TextStyle(fontSize: 18)),
        actions: [
          if (anyUnread)
            IconButton(
              tooltip: 'Marcar todos como leídos',
              icon: _markingAll
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _accentCyan),
                    )
                  : const Icon(Icons.done_all_rounded, color: _accentCyan),
              onPressed: _markingAll ? null : _markAllRead,
            ),
        ],
      ),
      body: RefreshIndicator(
        color: _accentCyan,
        onRefresh: _load,
        child: _body(avisos),
      ),
    );
  }

  Widget _body(List<Aviso> avisos) {
    final error = _error;
    if (_avisos == null && error == null && avisos.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _accentCyan));
    }
    return ListView(
      // Para que se pueda tirar hacia abajo aunque la lista sea corta.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (error != null)
          _ErrorBanner(message: error, onRetry: _load)
        else if (avisos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Text(
              'No tienes avisos vigentes. Cuando llegue uno de las alertas que '
              'activaste, aparecerá aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _secondaryTextColor, fontSize: 14),
            ),
          ),
        for (final aviso in avisos)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AvisoCard(
              aviso: aviso,
              highlighted: aviso.id == widget.opened?.id,
              catastrophe: widget.catastropheTypes.contains(aviso.type),
              onTap: () => _markRead(aviso),
              onSource: _openSource,
            ),
          ),
      ],
    );
  }
}

class _AvisoCard extends StatelessWidget {
  const _AvisoCard({
    required this.aviso,
    required this.highlighted,
    required this.catastrophe,
    required this.onTap,
    required this.onSource,
  });

  final Aviso aviso;
  final bool highlighted;
  final bool catastrophe;
  final VoidCallback onTap;
  final ValueChanged<Uri> onSource;

  @override
  Widget build(BuildContext context) {
    final unread = !aviso.read;
    final createdAt = aviso.createdAt;
    final targetDate = aviso.targetDate;
    final sourceUrl = aviso.sourceUrl;
    final border = highlighted
        ? _accentCyan
        : unread
            ? _amber.withValues(alpha: 0.45)
            : const Color(0x80475569);

    return Material(
      color: _cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border, width: highlighted ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: unread ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(avisoIcon(aviso.type), style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          aviso.title,
                          style: const TextStyle(
                            color: _textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (unread) const _NewPill(),
                      ],
                    ),
                    if (aviso.place.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '★ ${aviso.place}',
                        style: const TextStyle(color: _accentCyan, fontSize: 12),
                      ),
                    ],
                    if (aviso.text.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        aviso.text,
                        style: const TextStyle(color: _bodyColor, fontSize: 14, height: 1.35),
                      ),
                    ],
                    if (catastrophe) ...[
                      const SizedBox(height: 8),
                      const Text(
                        kGdacsDisclaimer,
                        style: TextStyle(color: _amber, fontSize: 12, height: 1.3),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        if (createdAt != null) _meta(arrivedLabel(createdAt, DateTime.now())),
                        if (targetDate != null) _meta('Para el ${dayLabel(targetDate)}'),
                        if (sourceUrl != null)
                          GestureDetector(
                            onTap: () => onSource(sourceUrl),
                            child: Text(
                              'Más información en ${aviso.source ?? 'la fuente'} ↗',
                              style: const TextStyle(color: _linkColor, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _meta(String text) =>
      Text(text, style: const TextStyle(color: _secondaryTextColor, fontSize: 12));
}

class _NewPill extends StatelessWidget {
  const _NewPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(color: _amber, borderRadius: BorderRadius.circular(999)),
      child: const Text(
        'NUEVO',
        style: TextStyle(
          color: _background,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
        ),
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

/// «Llegó hoy a las 15:30», «ayer» o con la fecha.
@visibleForTesting
String arrivedLabel(DateTime when, DateTime now) {
  // En UTC los días miden siempre 24 h, también con cambio de horario.
  final days = DateTime.utc(now.year, now.month, now.day)
      .difference(DateTime.utc(when.year, when.month, when.day))
      .inDays;
  final hour = '${_two(when.hour)}:${_two(when.minute)}';
  return switch (days) {
    0 => 'Llegó hoy a las $hour',
    1 => 'Llegó ayer a las $hour',
    _ => 'Llegó el ${_two(when.day)}-${_two(when.month)} a las $hour',
  };
}

/// `25-10-2026`, como la web.
@visibleForTesting
String dayLabel(DateTime day) => '${_two(day.day)}-${_two(day.month)}-${day.year}';

String _two(int n) => n.toString().padLeft(2, '0');

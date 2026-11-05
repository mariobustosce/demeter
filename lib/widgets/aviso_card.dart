import 'package:flutter/material.dart';

import '../models/aviso.dart';

const _background = Color(0xFF0A0A0F);
const _cardBackground = Color(0xFF0F172A);
const _accentCyan = Color(0xFF4FD0E7);
const _amber = Color(0xFFF59E0B);
const _textColor = Color(0xFFF7FAFC);
const _secondaryTextColor = Color(0xFF94A3B8);
const _bodyColor = Color(0xFFCBD5E1);
const _linkColor = Color(0xFF60A5FA);

/// Un aviso recibido, como en el «Historial de avisos» de la web. Tocar uno
/// nuevo lo marca leído.
class AvisoCard extends StatelessWidget {
  const AvisoCard({
    super.key,
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

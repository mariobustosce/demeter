import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/landscape.dart';
import '../services/landscape_thumbnails.dart';

const _accentCyan = Color(0xFF4FD0E7);
const _cardBackground = Color(0xEF0F172A);
const _textColor = Color(0xFFF7FAFC);
const _secondaryTextColor = Color(0xFF94A3B8);
const _skyColor = Color(0xFF1E293B);

/// La miniatura es una franja de unas 8 veces más ancha que alta: más angosta
/// que esto, no se distingue el paisaje.
const double _minTileWidth = 320;

/// Alto ÷ ancho del hueco mientras carga, parecido al de la franja.
const double _placeholderAspect = 7;

/// El catálogo de paisajes en columnas, en el orden que llega. Con
/// [selectedKey] marca el elegido (la clave del de siempre si el favorito no
/// tiene uno). Con [onBuy], los bloqueados llevan un botón «Comprar».
class LandscapeGrid extends StatelessWidget {
  const LandscapeGrid({
    super.key,
    required this.landscapes,
    this.selectedKey,
    this.onTap,
    this.onBuy,
    this.busyKey,
  });

  final List<Landscape> landscapes;
  final String? selectedKey;
  final ValueChanged<Landscape>? onTap;
  final ValueChanged<Landscape>? onBuy;

  /// El que se está guardando o comprando: va con una rueda y sin toques.
  final String? busyKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / _minTileWidth).floor().clamp(1, 4);
        return Column(
          children: [
            for (var i = 0; i < landscapes.length; i += columns)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var j = i; j < i + columns; j++) ...[
                      if (j > i) const SizedBox(width: 12),
                      Expanded(
                        child: j < landscapes.length
                            ? _tile(landscapes[j])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _tile(Landscape landscape) {
    final busy = busyKey != null;
    return LandscapeTile(
      landscape: landscape,
      selected: selectedKey == landscape.key,
      busy: busyKey == landscape.key,
      onTap: onTap == null || busy ? null : () => onTap!(landscape),
      onBuy: onBuy == null || busy || !landscape.locked
          ? null
          : () => onBuy!(landscape),
    );
  }
}

class LandscapeTile extends StatelessWidget {
  const LandscapeTile({
    super.key,
    required this.landscape,
    this.selected = false,
    this.busy = false,
    this.onTap,
    this.onBuy,
  });

  final Landscape landscape;
  final bool selected;
  final bool busy;
  final VoidCallback? onTap;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final badge = _badge();
    final borderColor = selected
        ? _accentCyan
        : Colors.white.withValues(alpha: landscape.locked ? 0.08 : 0.14);
    return Material(
      color: selected ? _accentCyan.withValues(alpha: 0.12) : _cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: selected ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Opacity(
              opacity: landscape.locked ? 0.7 : 1,
              child: LandscapeThumbnail(landscape: landscape),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (selected) ...[
                        const Icon(Icons.check_circle_rounded, color: _accentCyan, size: 16),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          landscape.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (busy)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _accentCyan),
                        )
                      else
                        ?badge,
                    ],
                  ),
                  if (landscape.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      landscape.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _secondaryTextColor, fontSize: 12),
                    ),
                  ],
                  if (onBuy != null) ...[
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: onBuy,
                      style: FilledButton.styleFrom(
                        backgroundColor: _accentCyan,
                        foregroundColor: _cardBackground,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        landscape.price == null
                            ? 'Comprar'
                            : 'Comprar por ${landscape.price} ✨',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Como en la web: el de siempre, 🔒 con el precio, o comprado.
  Widget? _badge() {
    if (landscape.isDefault) return const _Badge('El de siempre', Colors.amber);
    if (landscape.locked) {
      return _Badge(
        landscape.price == null ? '🔒' : '🔒 ${landscape.price} ✨',
        _secondaryTextColor,
      );
    }
    if (landscape.purchased) return const _Badge('Comprado ✓', Colors.greenAccent);
    return null;
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// La miniatura SVG del paisaje, de la caché de [LandscapeThumbnails].
class LandscapeThumbnail extends StatefulWidget {
  const LandscapeThumbnail({super.key, required this.landscape});

  final Landscape landscape;

  @override
  State<LandscapeThumbnail> createState() => _LandscapeThumbnailState();
}

class _LandscapeThumbnailState extends State<LandscapeThumbnail> {
  late Future<Uint8List?> _svg = _load();

  @override
  void didUpdateWidget(LandscapeThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.landscape.thumbnailUrl != widget.landscape.thumbnailUrl) {
      _svg = _load();
    }
  }

  Future<Uint8List?> _load() {
    final url = widget.landscape.thumbnailUrl;
    return url == null
        ? Future.value(null)
        : LandscapeThumbnails.instance.load(url);
  }

  @override
  Widget build(BuildContext context) {
    final label = 'Vista previa de ${widget.landscape.title}';
    return FutureBuilder<Uint8List?>(
      future: _svg,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          final done = snapshot.connectionState == ConnectionState.done;
          return _placeholder(label, failed: done);
        }
        return ColoredBox(
          color: _skyColor,
          child: SvgPicture.memory(
            bytes,
            fit: BoxFit.fitWidth,
            semanticsLabel: label,
            placeholderBuilder: (_) => _placeholder(label),
            errorBuilder: (_, _, _) => _placeholder(label, failed: true),
          ),
        );
      },
    );
  }

  static Widget _placeholder(String label, {bool failed = false}) {
    return Semantics(
      label: label,
      child: AspectRatio(
        aspectRatio: _placeholderAspect,
        child: ColoredBox(
          color: _skyColor,
          child: failed
              ? const Icon(Icons.landscape_outlined, color: _secondaryTextColor, size: 20)
              : null,
        ),
      ),
    );
  }
}

/// Pregunta antes de gastar polvo, como la web.
Future<bool> confirmLandscapePurchase(BuildContext context, Landscape landscape) async {
  final price = landscape.price == null ? '' : ' por ${landscape.price} ✨';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      title: Text(
        '¿Comprar «${landscape.title}»$price?',
        style: const TextStyle(color: _textColor, fontSize: 18),
      ),
      content: const Text(
        'Se descuenta de tu Polvo Estelar. Es un pago único: después lo puedes '
        'usar en todos tus lugares.',
        style: TextStyle(color: _secondaryTextColor, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar', style: TextStyle(color: _secondaryTextColor)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(
            backgroundColor: _accentCyan,
            foregroundColor: _cardBackground,
          ),
          child: const Text('Comprar'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

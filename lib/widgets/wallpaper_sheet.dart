import 'package:flutter/material.dart';

import '../models/favorite.dart';
import '../models/wallpaper_link.dart';
import '../services/api_client.dart';
import '../services/favorites_service.dart';
import '../services/live_wallpaper.dart';
import '../services/wallpaper_links_service.dart';

const _accentCyan = Color(0xFF4FD0E7);
const _sheetBackground = Color(0xFF0F172A);
const _textColor = Color(0xFFF7FAFC);
const _secondaryTextColor = Color(0xFF94A3B8);

/// Hoja del fondo animado (solo Android): se elige un favorito y un modo, y se
/// abre el selector de Android con nuestro fondo. Si ya está puesto, solo
/// cambia lo que muestra. Aquí también se desbloquea el rotativo y se regenera
/// el enlace. Sin favoritos, [onCreateFavorite] lleva a guardar uno.
Future<void> showWallpaperSheet(
  BuildContext context, {
  required VoidCallback onCreateFavorite,
  FavoritesService? favorites,
  WallpaperLinksService? links,
  LiveWallpaper? wallpaper,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WallpaperSheet(
        onCreateFavorite: onCreateFavorite,
        favorites: favorites ?? FavoritesService(),
        links: links ?? WallpaperLinksService(),
        wallpaper: wallpaper ?? LiveWallpaper.instance,
      ),
    );

class _WallpaperSheet extends StatefulWidget {
  const _WallpaperSheet({
    required this.onCreateFavorite,
    required this.favorites,
    required this.links,
    required this.wallpaper,
  });

  final VoidCallback onCreateFavorite;
  final FavoritesService favorites;
  final WallpaperLinksService links;
  final LiveWallpaper wallpaper;

  @override
  State<_WallpaperSheet> createState() => _WallpaperSheetState();
}

class _WallpaperSheetState extends State<_WallpaperSheet> {
  bool _supported = true;
  List<Favorite>? _favorites;
  String? _loadError;

  WallpaperChoice? _current; // lo guardado en el teléfono
  bool _active = false; // el fondo de pantalla es el nuestro

  int? _favoriteId;
  WallpaperLink? _link; // el del favorito elegido
  String? _linkError;
  WallpaperMode _mode = WallpaperMode.basico;

  ({String text, bool error})? _notice;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Favorite? get _favorite =>
      _favorites?.where((f) => f.id == _favoriteId).firstOrNull;

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      if (!await widget.wallpaper.isSupported()) {
        if (mounted) setState(() => _supported = false);
        return;
      }
      final results = await Future.wait<Object?>([
        widget.favorites.list(),
        widget.wallpaper.current(),
        widget.wallpaper.isActive(),
      ]);
      if (!mounted) return;
      final favorites = results[0] as List<Favorite>;
      final current = results[1] as WallpaperChoice?;
      // Abre en lo que ya está puesto, si ese lugar sigue en favoritos.
      final saved = favorites.where((f) => f.id == current?.favoriteId).firstOrNull;
      setState(() {
        _favorites = favorites;
        _current = current;
        _active = results[2] as bool;
        _favoriteId = (saved ?? favorites.firstOrNull)?.id;
        if (saved != null) _mode = current!.mode;
      });
      await _loadLink();
    } on UnauthorizedException {
      if (mounted) Navigator.pop(context); // El ApiClient ya llevó al invitado.
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } catch (e) {
      debugPrint('Fondo animado: favoritos no disponibles (${e.runtimeType}).');
      if (mounted) setState(() => _loadError = 'No se pudieron cargar tus lugares.');
    }
  }

  Future<void> _loadLink() async {
    final id = _favoriteId;
    if (id == null) return;
    setState(() {
      _link = null;
      _linkError = null;
      _notice = null;
    });
    try {
      final link = await widget.links.get(id);
      if (!mounted || id != _favoriteId) return;
      setState(() {
        _link = link;
        if (_mode == WallpaperMode.rotativo && !link.rotatingUnlocked) {
          _mode = WallpaperMode.basico;
        }
      });
    } on UnauthorizedException {
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted && id == _favoriteId) {
        setState(() => _linkError = FavoritesService.messageFor(e));
      }
    } catch (e) {
      debugPrint('Fondo animado: enlace no disponible (${e.runtimeType}).');
      if (mounted && id == _favoriteId) {
        setState(() => _linkError = 'No se pudo cargar el fondo de este lugar.');
      }
    }
  }

  void _selectFavorite(int? id) {
    if (id == null || id == _favoriteId) return;
    setState(() => _favoriteId = id);
    _loadLink();
  }

  void _selectMode(WallpaperMode mode) {
    if (mode == WallpaperMode.rotativo && _link?.rotatingUnlocked != true) {
      _unlockRotating();
      return;
    }
    setState(() => _mode = mode);
  }

  /// Corre [action] con el botón ocupado y muestra lo que falle.
  Future<void> _run(String failure, Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action();
    } on UnauthorizedException {
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) setState(() => _notice = (text: FavoritesService.messageFor(e), error: true));
    } catch (e) {
      debugPrint('Fondo animado: $failure (${e.runtimeType}).');
      if (mounted) setState(() => _notice = (text: failure, error: true));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlockRotating() async {
    final id = _favoriteId;
    final link = _link;
    if (id == null || link == null || _busy) return;
    final price = link.rotatingPrice == null ? '' : ' por ${link.rotatingPrice} ✨';
    final confirmed = await _confirm(
      title: '¿Desbloquear el modo rotativo$price?',
      body: 'Muestra un paisaje distinto cada 5 minutos. Es un pago único para '
          'este lugar, con tu Polvo Estelar, y sirve también en Lively del PC.',
      action: 'Desbloquear',
    );
    if (!confirmed || !mounted) return;
    await _run('No se pudo completar la compra.', () async {
      final unlocked = await widget.links.unlockRotating(id);
      if (!mounted || id != _favoriteId) return;
      setState(() {
        _link = unlocked;
        _mode = WallpaperMode.rotativo;
      });
    });
  }

  /// Crea el enlace si hace falta, se lo pasa al servicio y abre el selector
  /// de Android. Si el fondo ya es el nuestro, basta con guardarlo.
  Future<void> _apply() async {
    final favorite = _favorite;
    var link = _link;
    if (favorite == null || link == null) return;
    final mode = _mode;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await _run('No se pudo poner el fondo.', () async {
      if (!link!.exists) {
        link = await widget.links.create(favorite.id);
        if (!mounted) return;
        setState(() => _link = link);
      }
      final url = link!.urls[mode];
      if (url == null) {
        setState(() => _notice = (text: 'Ese modo no está disponible para este lugar.', error: true));
        return;
      }
      await widget.wallpaper.configure(url, favoriteId: favorite.id, mode: mode);
      _current = (favoriteId: favorite.id, mode: mode);

      if (await widget.wallpaper.isActive()) {
        if (!mounted) return;
        Navigator.pop(context);
        messenger?.showSnackBar(SnackBar(
          content: Text('Fondo animado: ${favorite.title} · ${mode.label}'),
        ));
        return;
      }
      final opened = await widget.wallpaper.openPicker();
      if (!mounted) return;
      if (opened) {
        Navigator.pop(context);
      } else {
        setState(() => _notice = (
              text: 'Tu teléfono no deja abrir el selector de fondos animados. '
                  'Búscalo en Ajustes → Fondo de pantalla.',
              error: true,
            ));
      }
    });
  }

  /// Token nuevo: el anterior deja de funcionar. Si el fondo del teléfono es
  /// de este lugar, sigue con el enlace nuevo.
  Future<void> _regenerate() async {
    final id = _favoriteId;
    if (id == null || _busy) return;
    final confirmed = await _confirm(
      title: '¿Regenerar el enlace del fondo?',
      body: 'El enlace actual deja de funcionar al instante, también en Lively '
          'del PC: allí hay que volver a ponerlo. En este teléfono se cambia solo.',
      action: 'Regenerar',
    );
    if (!confirmed || !mounted) return;
    await _run('No se pudo regenerar el enlace.', () async {
      final link = await widget.links.regenerate(id);
      final current = _current;
      if (current != null && current.favoriteId == id) {
        final mode = link.urls.containsKey(current.mode) ? current.mode : WallpaperMode.basico;
        final url = link.urls[mode];
        if (url != null) {
          await widget.wallpaper.configure(url, favoriteId: id, mode: mode);
          _current = (favoriteId: id, mode: mode);
        }
      }
      if (!mounted || id != _favoriteId) return;
      setState(() {
        _link = link;
        _notice = (text: 'Enlace nuevo listo. El anterior ya no funciona.', error: false);
      });
    });
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _sheetBackground,
        title: Text(title, style: const TextStyle(color: _textColor, fontSize: 18)),
        content: Text(body, style: const TextStyle(color: _secondaryTextColor, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar', style: TextStyle(color: _secondaryTextColor)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: _accentCyan,
              foregroundColor: _sheetBackground,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '🌌 Fondo animado',
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close_rounded, color: _secondaryTextColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Text(
                'El cielo de uno de tus lugares como fondo de pantalla, con su '
                'clima y su animación.',
                style: TextStyle(color: _secondaryTextColor, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ..._content(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content() {
    if (!_supported) {
      return const [_Hint('Tu teléfono no admite fondos animados.')];
    }
    final favorites = _favorites;
    final loadError = _loadError;
    if (loadError != null) {
      return [_Hint(loadError), TextButton(onPressed: _load, child: const Text('Reintentar'))];
    }
    if (favorites == null) return const [_Spinner()];
    if (favorites.isEmpty) {
      return [
        const _Hint(
          'El fondo muestra uno de tus lugares favoritos. Guarda uno en el '
          'mapa con ☆ y vuelve aquí.',
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onCreateFavorite();
          },
          style: FilledButton.styleFrom(
            backgroundColor: _accentCyan,
            foregroundColor: _sheetBackground,
          ),
          child: const Text('Guardar un favorito'),
        ),
      ];
    }

    final link = _link;
    final linkError = _linkError;
    final notice = _notice;
    final current = _current;
    final isCurrent = _active && current?.favoriteId == _favoriteId && current?.mode == _mode;
    return [
      const _Label('Lugar'),
      DropdownButton<int>(
        value: _favoriteId,
        isExpanded: true,
        dropdownColor: _sheetBackground,
        iconEnabledColor: _textColor,
        style: const TextStyle(color: _textColor, fontSize: 15),
        underline: Container(height: 1, color: _accentCyan.withValues(alpha: 0.4)),
        onChanged: _busy ? null : _selectFavorite,
        items: [
          for (final favorite in favorites)
            DropdownMenuItem(
              value: favorite.id,
              child: Text(favorite.title, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
      const SizedBox(height: 16),
      const _Label('Modo'),
      if (linkError != null) ...[
        _Hint(linkError),
        TextButton(onPressed: _loadLink, child: const Text('Reintentar')),
      ] else if (link == null)
        const _Spinner()
      else ...[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final mode in WallpaperMode.values) _modeChip(mode, link),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Rotativo: un paisaje distinto cada 5 minutos.',
          style: TextStyle(color: _secondaryTextColor, fontSize: 11),
        ),
      ],
      if (notice != null) _NoticeBox(notice.text, error: notice.error),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _busy || link == null ? null : _apply,
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _sheetBackground),
              )
            : Icon(isCurrent ? Icons.check_rounded : Icons.wallpaper_rounded),
        label: Text(_active ? 'Actualizar el fondo' : 'Poner de fondo'),
        style: FilledButton.styleFrom(
          backgroundColor: _accentCyan,
          foregroundColor: _sheetBackground,
          disabledBackgroundColor: _accentCyan.withValues(alpha: 0.3),
        ),
      ),
      if (link?.exists == true)
        TextButton(
          onPressed: _busy ? null : _regenerate,
          child: const Text(
            'Regenerar el enlace',
            style: TextStyle(color: _secondaryTextColor),
          ),
        ),
    ];
  }

  Widget _modeChip(WallpaperMode mode, WallpaperLink link) {
    final locked = mode == WallpaperMode.rotativo && !link.rotatingUnlocked;
    final price = link.rotatingPrice;
    final label = locked
        ? '${mode.label} · 🔒${price == null ? '' : ' $price ✨'}'
        : mode.label;
    final selected = mode == _mode;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: _busy ? null : (_) => _selectMode(mode),
      showCheckmark: false,
      backgroundColor: _sheetBackground,
      selectedColor: _accentCyan.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: selected ? _accentCyan : _textColor,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: _accentCyan.withValues(alpha: selected ? 0.8 : 0.3)),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: const TextStyle(
            color: _secondaryTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _secondaryTextColor, fontSize: 14),
      );
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: _accentCyan)),
      );
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox(this.text, {required this.error});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? Colors.redAccent : _accentCyan;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: const TextStyle(color: _textColor, fontSize: 13)),
    );
  }
}

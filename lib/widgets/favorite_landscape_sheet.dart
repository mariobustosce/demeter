import 'package:flutter/material.dart';

import '../models/favorite.dart';
import '../models/landscape.dart';
import '../services/api_client.dart';
import '../services/favorites_service.dart';
import '../services/landscapes_service.dart';
import 'landscape_grid.dart';

const _accentCyan = Color(0xFF4FD0E7);
const _sheetBackground = Color(0xFF0F172A);
const _textColor = Color(0xFFF7FAFC);
const _secondaryTextColor = Color(0xFF94A3B8);

/// El paisaje que quedó en el favorito, y si hubo que comprarlo.
typedef LandscapeChoice = ({Landscape landscape, bool bought});

/// Hoja 🏞 para elegir el paisaje de [favorite]. Un paisaje con 🔒 se compra
/// ahí mismo (con confirmación) y queda puesto. Devuelve `null` si no cambió.
Future<LandscapeChoice?> showFavoriteLandscapeSheet(
  BuildContext context,
  Favorite favorite, {
  FavoritesService? favorites,
  LandscapesService? landscapes,
}) =>
    showModalBottomSheet<LandscapeChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FavoriteLandscapeSheet(
        favorite: favorite,
        favorites: favorites ?? FavoritesService(),
        landscapes: landscapes ?? LandscapesService(),
      ),
    );

class _FavoriteLandscapeSheet extends StatefulWidget {
  const _FavoriteLandscapeSheet({
    required this.favorite,
    required this.favorites,
    required this.landscapes,
  });

  final Favorite favorite;
  final FavoritesService favorites;
  final LandscapesService landscapes;

  @override
  State<_FavoriteLandscapeSheet> createState() => _FavoriteLandscapeSheetState();
}

class _FavoriteLandscapeSheetState extends State<_FavoriteLandscapeSheet> {
  List<Landscape>? _catalog;
  String? _current; // null: el de siempre
  String? _loadError;
  String? _message; // lo último que falló al elegir o comprar
  String? _busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final results = await Future.wait<Object?>([
        widget.landscapes.catalog(),
        widget.favorites.landscapeOf(widget.favorite.id),
      ]);
      if (!mounted) return;
      setState(() {
        _catalog = results[0] as List<Landscape>;
        _current = results[1] as String?;
      });
    } on UnauthorizedException {
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = FavoritesService.messageFor(e));
    } catch (e) {
      debugPrint('Paisaje del lugar no disponible (${e.runtimeType}).');
      if (mounted) setState(() => _loadError = 'No se pudo cargar el catálogo.');
    }
  }

  String? get _selectedKey =>
      _current ?? _catalog?.where((l) => l.isDefault).firstOrNull?.key;

  Future<void> _onTap(Landscape landscape) async {
    if (_busy != null || landscape.key == _selectedKey) return;
    if (landscape.locked) return _buyAndUse(landscape);
    await _use(landscape, bought: false);
  }

  Future<void> _buyAndUse(Landscape landscape) async {
    if (!await confirmLandscapePurchase(context, landscape) || !mounted) return;
    setState(() {
      _busy = landscape.key;
      _message = null;
    });
    try {
      final bought = await widget.landscapes.buy(landscape.key);
      if (!mounted) return;
      setState(() => _catalog = [
            for (final l in _catalog ?? const <Landscape>[])
              l.key == bought.key ? bought : l,
          ]);
      await _use(bought, bought: true);
    } on UnauthorizedException {
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) setState(() => _message = e.message);
      // Ya lo podía usar, o cambió el precio: el catálogo estaba viejo.
      if (e is ValidationException && mounted) await _load();
    } catch (e) {
      debugPrint('No se pudo comprar el paisaje (${e.runtimeType}).');
      if (mounted) setState(() => _message = 'No se pudo completar la compra.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _use(Landscape landscape, {required bool bought}) async {
    setState(() {
      _busy = landscape.key;
      _message = null;
    });
    try {
      // El de siempre se guarda como «sin paisaje».
      await widget.favorites.setLandscape(
        widget.favorite.id,
        landscape.isDefault ? null : landscape.key,
      );
      if (mounted) Navigator.pop(context, (landscape: landscape, bought: bought));
    } on UnauthorizedException {
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      final message = FavoritesService.messageFor(e);
      if (mounted) {
        setState(() => _message = bought
            ? 'Ya es tuyo, pero no se pudo poner en este lugar: $message'
            : message);
      }
    } catch (e) {
      debugPrint('No se pudo cambiar el paisaje (${e.runtimeType}).');
      if (mounted) setState(() => _message = 'No se pudo guardar el paisaje.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final message = _message;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '🏞 ${widget.favorite.title}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
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
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Elige el paisaje de este lugar. Los que tienen 🔒 se compran '
                'una vez con Polvo Estelar y sirven para todos tus lugares.',
                style: TextStyle(color: _secondaryTextColor, fontSize: 12),
              ),
            ),
            if (message != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  message,
                  style: const TextStyle(color: _textColor, fontSize: 13),
                ),
              ),
            const SizedBox(height: 12),
            Flexible(child: _content()),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final catalog = _catalog;
    final error = _loadError;
    if (catalog == null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: error == null
            ? const Center(child: CircularProgressIndicator(color: _accentCyan))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _secondaryTextColor),
                  ),
                  TextButton(onPressed: _load, child: const Text('Reintentar')),
                ],
              ),
      );
    }
    if (catalog.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Todavía no hay paisajes disponibles.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _secondaryTextColor),
        ),
      );
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        LandscapeGrid(
          landscapes: catalog,
          selectedKey: _selectedKey,
          onTap: _onTap,
          busyKey: _busy,
        ),
      ],
    );
  }
}

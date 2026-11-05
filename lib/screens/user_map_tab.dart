import 'package:flutter/material.dart';

import '../models/favorite.dart';
import '../models/map_mode.dart';
import '../services/api_client.dart';
import '../services/favorites_service.dart';
import '../services/location_service.dart';
import '../services/map_urls.dart';
import '../services/map_view_service.dart';
import '../services/place_search.dart';
import '../widgets/explore_place_sheet.dart';
import '../widgets/favorite_landscape_sheet.dart';
import '../widgets/location_prompt.dart';
import '../widgets/map_mode_menu.dart';
import '../widgets/map_web_view.dart';

const _accentCyan = Color(0xFF4FD0E7);
const _cardBackground = Color(0xEF0F172A);
const _sheetBackground = Color(0xFF0F172A);
const _textColor = Color(0xFFF7FAFC);
const _secondaryTextColor = Color(0xFF94A3B8);

/// Máximo que acepta el servidor para el nombre de un favorito.
const int _maxTitleLength = 60;

enum _FavoriteAction { landscape, rename, remove }

/// Pestaña DEMETER con sesión: el mapa del token de vista, con un botón que
/// despliega «Mi ubicación» y los favoritos. «Mi ubicación» se guarda con ★;
/// un favorito tiene sus opciones en ⋮ (el que se ve, junto al botón; los
/// demás, en la lista): paisaje, nombre y quitar. Con 🔍 se explora otro
/// lugar, buscado o por coordenadas, y se puede guardar como favorito.
class UserMapTab extends StatefulWidget {
  const UserMapTab({
    super.key,
    required this.active,
    this.footer,
    this.favorites,
    this.placeSearch,
  });

  /// `false` con otra pestaña a la vista: el WebView sale del árbol para que
  /// no siga animando oculto.
  final bool active;

  /// Bajo el mapa, con alto fijo para que el mapa no cambie de tamaño.
  final Widget? footer;

  final FavoritesService? favorites;
  final PlaceSearchService? placeSearch;

  @override
  State<UserMapTab> createState() => _UserMapTabState();
}

class _UserMapTabState extends State<UserMapTab>
    with AutomaticKeepAliveClientMixin {
  late final FavoritesService _favoritesService =
      widget.favorites ?? FavoritesService();

  List<Favorite> _favorites = const [];
  int? _favoriteId; // null: «Mi ubicación» u otro lugar explorado
  String? _placeName; // el lugar explorado; null: «Mi ubicación»
  RoundedLocation? _location;
  MapMode _mode = MapMode.basico;
  bool _ready = false;
  bool _saving = false;

  // Sube cuando cambia lo que dibuja la página sin que cambie su URL (el
  // paisaje o el nombre del favorito): así el mapa se recarga.
  int _mapVersion = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final mode = await loadMapMode();
    var favorites = const <Favorite>[];
    try {
      favorites = await _favoritesService.list();
    } on UnauthorizedException {
      return; // El ApiClient ya llevó al mapa de invitado.
    } catch (e) {
      debugPrint('Favoritos no disponibles (${e.runtimeType}).');
    }
    if (!mounted) return;

    // Como en la web: con favoritos se abre el primero; sin ellos, donde está.
    RoundedLocation? location;
    if (favorites.isEmpty) {
      location = await mapLocation(context);
      if (!mounted) return;
    }
    setState(() {
      _mode = mode;
      _favorites = favorites;
      _favoriteId = favorites.firstOrNull?.id;
      _location = location;
      _ready = true;
    });
  }

  Future<void> _selectMyLocation() async {
    final location = await mapLocation(context, userAsked: true);
    if (!mounted) return;
    // Sin ubicación, el servidor mostraría el favorito más antiguo: mejor
    // quedarse en el favorito que se estaba viendo.
    if (location == null && _favoriteId != null) return;
    setState(() {
      _favoriteId = null;
      _placeName = null;
      _location = location;
    });
  }

  void _selectFavorite(Favorite favorite) =>
      setState(() => _favoriteId = favorite.id);

  /// Otro lugar, buscado o por coordenadas: se ve en el mapa y, si el
  /// usuario quiere, se guarda en sus favoritos.
  Future<void> _explore() async {
    final place = await showExplorePlaceSheet(context, search: widget.placeSearch);
    if (!mounted || place == null) return;
    setState(() {
      _favoriteId = null;
      _placeName = place.name;
      _location = place.location;
    });
    if (place.save) await _saveCurrentPlace(title: place.name);
  }

  void _setMode(MapMode mode) {
    setState(() => _mode = mode);
    saveMapMode(mode);
  }

  Future<Uri> _buildUrl(double ratio, {bool renew = false}) async {
    final view = await MapViewService.instance.get(renew: renew);
    return MapUrls.user(
      view.baseUrl,
      _mode,
      favoriteId: _favoriteId,
      location: _location,
      ratio: ratio,
    );
  }

  void _notify(String message, {bool error = false}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.redAccent : null,
    ));
  }

  /// Guarda el lugar que se ve («Mi ubicación» o el explorado) con los mismos
  /// 2 decimales del mapa y pasa a verlo como favorito. El tope lo pone el
  /// servidor y su mensaje se muestra tal cual.
  Future<void> _saveCurrentPlace({String? title}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final location = _location ?? await mapLocation(context, userAsked: true);
      if (!mounted) return;
      if (location == null) {
        _notify('Para guardar este lugar hace falta tu ubicación.');
        return;
      }

      final saved = await _favoritesService.save(location, title: title ?? _placeName);
      if (!mounted) return;
      final favorite = saved.favorite;
      setState(() {
        if (!_favorites.any((f) => f.id == favorite.id)) {
          _favorites = [..._favorites, favorite];
        }
        _favoriteId = favorite.id;
        _location = location;
      });
      _notify(saved.existing
          ? '★ Ya estaba en tus favoritos: ${favorite.title}'
          : '★ Guardado: ${favorite.title}');
    } on UnauthorizedException {
      // El ApiClient ya llevó al mapa de invitado.
    } on ApiException catch (e) {
      _notify(e.message, error: true);
    } catch (e) {
      debugPrint('No se pudo guardar el favorito (${e.runtimeType}).');
      _notify('No se pudo guardar el lugar.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openActions(Favorite favorite) async {
    final action = await showModalBottomSheet<_FavoriteAction>(
      context: context,
      backgroundColor: _sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FavoriteActionsSheet(favorite: favorite),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _FavoriteAction.landscape:
        await _chooseLandscape(favorite);
      case _FavoriteAction.rename:
        await _rename(favorite);
      case _FavoriteAction.remove:
        await _remove(favorite);
    }
  }

  Future<void> _chooseLandscape(Favorite favorite) async {
    final choice = await showFavoriteLandscapeSheet(
      context,
      favorite,
      favorites: _favoritesService,
    );
    if (!mounted || choice == null) return;
    // La URL del favorito no cambia con su paisaje.
    if (favorite.id == _favoriteId) setState(() => _mapVersion++);
    final title = choice.landscape.title;
    _notify(choice.bought
        ? '¡Tuyo! «$title» ya está en ${favorite.title}.'
        : 'Paisaje cambiado a «$title»');
  }

  Future<void> _rename(Favorite favorite) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(current: favorite.title),
    );
    if (!mounted || title == null || title == favorite.title) return;
    try {
      final renamed = await _favoritesService.rename(favorite.id, title);
      if (!mounted) return;
      setState(() {
        _favorites = [
          for (final f in _favorites) f.id == renamed.id ? renamed : f,
        ];
        // La cabecera del mapa lleva el nombre del lugar.
        if (renamed.id == _favoriteId) _mapVersion++;
      });
      _notify('Nombre guardado');
    } on UnauthorizedException {
      return;
    } on ApiException catch (e) {
      _notify(FavoritesService.messageFor(e), error: true);
    } catch (e) {
      debugPrint('No se pudo renombrar el favorito (${e.runtimeType}).');
      _notify('No se pudo cambiar el nombre.', error: true);
    }
  }

  Future<void> _remove(Favorite favorite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _RemoveDialog(favorite: favorite),
    );
    if (!mounted || confirmed != true) return;
    try {
      await _favoritesService.delete(favorite.id);
    } on UnauthorizedException {
      return;
    } on ApiException catch (e) {
      // Si ya no existía, se quita igual de la lista.
      if (e.statusCode != 404) {
        _notify(FavoritesService.messageFor(e), error: true);
        return;
      }
    } catch (e) {
      debugPrint('No se pudo quitar el favorito (${e.runtimeType}).');
      _notify('No se pudo quitar.', error: true);
      return;
    }
    if (!mounted) return;

    final rest = [
      for (final f in _favorites)
        if (f.id != favorite.id) f,
    ];
    final wasShown = favorite.id == _favoriteId;
    // Como al entrar: el primer favorito que quede o, sin ninguno, donde está.
    var location = _location;
    if (wasShown && rest.isEmpty) {
      location ??= await mapLocation(context);
      if (!mounted) return;
    }
    setState(() {
      _favorites = rest;
      if (wasShown) {
        _favoriteId = rest.firstOrNull?.id;
        _location = location;
      }
    });
    _notify('Quitado de favoritos');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final favoriteId = _favoriteId;
    final shown = _favorites.where((f) => f.id == favoriteId).firstOrNull;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _PlaceMenu(
                    favorites: _favorites,
                    shown: shown,
                    exploredName: favoriteId == null ? _placeName : null,
                    enabled: _ready,
                    onExplore: _explore,
                    onMyLocation: _selectMyLocation,
                    onFavorite: _selectFavorite,
                    onOptions: _openActions,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _RoundButton(
                icon: Icons.travel_explore_rounded,
                tooltip: 'Explorar otro lugar',
                onPressed: _ready ? _explore : null,
              ),
              const SizedBox(width: 8),
              if (shown != null)
                _RoundButton(
                  icon: Icons.more_vert_rounded,
                  tooltip: 'Opciones de este lugar',
                  onPressed: () => _openActions(shown),
                )
              else
                _RoundButton(
                  icon: Icons.star_border_rounded,
                  tooltip: 'Guardar en favoritos',
                  busy: _saving,
                  onPressed: _ready && favoriteId == null ? _saveCurrentPlace : null,
                ),
              const SizedBox(width: 8),
              MapModeMenu(mode: _mode, onChanged: _setMode),
            ],
          ),
        ),
        Expanded(
          child: MapWebView(
            target: _ready
                ? (_mode, favoriteId, favoriteId == null ? _location : null, _mapVersion)
                : null,
            buildUrl: _buildUrl,
            visible: widget.active,
          ),
        ),
        ?widget.footer,
      ],
    );
  }
}

/// El lugar que se ve, en un botón que despliega «Explorar otro lugar», «Mi
/// ubicación» y los favoritos, como la web en el teléfono. Una fila de chips
/// no cabía junto al modo: se veían uno y medio, y el resto quedaba fuera de
/// la pantalla.
class _PlaceMenu extends StatelessWidget {
  const _PlaceMenu({
    required this.favorites,
    required this.shown,
    required this.exploredName,
    required this.enabled,
    required this.onExplore,
    required this.onMyLocation,
    required this.onFavorite,
    required this.onOptions,
  });

  final List<Favorite> favorites;
  final Favorite? shown; // null: «Mi ubicación» o el lugar explorado
  final String? exploredName; // null: «Mi ubicación»
  final bool enabled;
  final VoidCallback onExplore;
  final VoidCallback onMyLocation;
  final ValueChanged<Favorite> onFavorite;
  final ValueChanged<Favorite> onOptions;

  @override
  Widget build(BuildContext context) {
    final shown = this.shown;
    final explored = shown == null ? exploredName : null;
    // Cada opción lleva lo que hace al elegirla.
    return PopupMenuButton<VoidCallback>(
      tooltip: 'Favoritos',
      enabled: enabled,
      onSelected: (action) => action(),
      color: _sheetBackground,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: onExplore,
          child: const Row(
            children: [
              Icon(Icons.travel_explore_rounded, size: 18, color: _accentCyan),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Explorar otro lugar…',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _accentCyan, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (explored != null)
          _item(
            icon: Icons.place_rounded,
            label: explored,
            selected: true,
            action: () {},
          ),
        _item(
          icon: Icons.my_location_rounded,
          label: 'Mi ubicación',
          selected: shown == null && explored == null,
          action: onMyLocation,
        ),
        const PopupMenuDivider(),
        for (final favorite in favorites)
          _item(
            icon: Icons.star_rounded,
            label: favorite.title,
            selected: favorite.id == shown?.id,
            action: () => onFavorite(favorite),
            options: () => onOptions(favorite),
          ),
        if (favorites.isEmpty)
          const PopupMenuItem(
            enabled: false,
            child: Text(
              'Aún no tienes favoritos. Guarda este lugar con ☆.',
              style: TextStyle(color: _secondaryTextColor, fontSize: 13),
            ),
          ),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.only(left: 12, right: 6),
        decoration: BoxDecoration(
          color: _cardBackground,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: _accentCyan.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              shown != null
                  ? Icons.star_rounded
                  : explored != null
                      ? Icons.place_rounded
                      : Icons.my_location_rounded,
              color: enabled ? _accentCyan : _secondaryTextColor,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                shown?.title ?? explored ?? 'Mi ubicación',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: _textColor, size: 18),
          ],
        ),
      ),
    );
  }

  /// Con [options], un ⋮ que cierra la lista y abre las opciones del favorito.
  PopupMenuItem<VoidCallback> _item({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback action,
    VoidCallback? options,
  }) {
    return PopupMenuItem(
      value: action,
      padding: EdgeInsets.only(left: 12, right: options == null ? 12 : 0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: selected ? _accentCyan : _secondaryTextColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _textColor,
                fontSize: 14,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (options != null)
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Opciones de «$label»',
                icon: const Icon(Icons.more_vert_rounded, size: 18),
                color: _secondaryTextColor,
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.pop(context, options),
              ),
            ),
        ],
      ),
    );
  }
}

/// Botón redondo del alto del selector de modo.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _accentCyan),
            )
          : Icon(icon, size: 18),
      color: _accentCyan,
      disabledColor: _secondaryTextColor.withValues(alpha: 0.5),
      style: IconButton.styleFrom(
        backgroundColor: _cardBackground,
        fixedSize: const Size.square(34),
        minimumSize: const Size.square(34),
        padding: EdgeInsets.zero,
        side: BorderSide(color: _accentCyan.withValues(alpha: 0.3)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _FavoriteActionsSheet extends StatelessWidget {
  const _FavoriteActionsSheet({required this.favorite});

  final Favorite favorite;

  @override
  Widget build(BuildContext context) {
    void choose(_FavoriteAction action) => Navigator.pop(context, action);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                favorite.title,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.landscape_rounded, color: _accentCyan),
              title: const Text('Paisaje de este lugar', style: TextStyle(color: _textColor)),
              onTap: () => choose(_FavoriteAction.landscape),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: _accentCyan),
              title: const Text('Cambiar el nombre', style: TextStyle(color: _textColor)),
              onTap: () => choose(_FavoriteAction.rename),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text('Quitar de favoritos', style: TextStyle(color: _textColor)),
              onTap: () => choose(_FavoriteAction.remove),
            ),
          ],
        ),
      ),
    );
  }
}

/// Devuelve el nombre nuevo, sin espacios a los lados, o `null` si cancela.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.current});

  final String current;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current,
  )..selection = TextSelection(baseOffset: 0, extentOffset: widget.current.length);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isNotEmpty) Navigator.pop(context, title);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _sheetBackground,
      title: const Text(
        'Cambiar el nombre',
        style: TextStyle(color: _textColor, fontSize: 18),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: _maxTitleLength,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        style: const TextStyle(color: _textColor),
        decoration: const InputDecoration(
          counterStyle: TextStyle(color: _secondaryTextColor),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: _secondaryTextColor),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: _accentCyan),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: _secondaryTextColor)),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => FilledButton(
            onPressed: value.text.trim().isEmpty ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _accentCyan,
              foregroundColor: _sheetBackground,
            ),
            child: const Text('Guardar'),
          ),
        ),
      ],
    );
  }
}

/// Avisa que con el favorito se va su fondo animado, como pide el servidor.
class _RemoveDialog extends StatelessWidget {
  const _RemoveDialog({required this.favorite});

  final Favorite favorite;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _sheetBackground,
      title: Text(
        '¿Quitar «${favorite.title}» de tus favoritos?',
        style: const TextStyle(color: _textColor, fontSize: 18),
      ),
      content: const Text(
        'También se borra su fondo animado (el del teléfono y el de Lively en '
        'el PC) y el modo rotativo que hayas comprado para este lugar.',
        style: TextStyle(color: _secondaryTextColor, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar', style: TextStyle(color: _secondaryTextColor)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
          ),
          child: const Text('Quitar'),
        ),
      ],
    );
  }
}

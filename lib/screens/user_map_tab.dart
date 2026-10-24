import 'package:flutter/material.dart';

import '../models/favorite.dart';
import '../models/map_mode.dart';
import '../services/api_client.dart';
import '../services/favorites_service.dart';
import '../services/location_service.dart';
import '../services/map_urls.dart';
import '../services/map_view_service.dart';
import '../widgets/location_prompt.dart';
import '../widgets/map_mode_menu.dart';
import '../widgets/map_web_view.dart';

const _accentCyan = Color(0xFF4FD0E7);
const _cardBackground = Color(0xEF0F172A);
const _textColor = Color(0xFFF7FAFC);
const _secondaryTextColor = Color(0xFF94A3B8);

/// Pestaña MAPA con sesión: el mapa del token de vista, con chips de
/// «Mi ubicación» y de los favoritos.
class UserMapTab extends StatefulWidget {
  const UserMapTab({super.key, required this.active, this.footer});

  /// `false` con otra pestaña a la vista: el WebView sale del árbol para que
  /// no siga animando oculto.
  final bool active;

  /// Bajo el mapa, con alto fijo para que el mapa no cambie de tamaño.
  final Widget? footer;

  @override
  State<UserMapTab> createState() => _UserMapTabState();
}

class _UserMapTabState extends State<UserMapTab>
    with AutomaticKeepAliveClientMixin {
  final FavoritesService _favoritesService = FavoritesService();

  List<Favorite> _favorites = const [];
  int? _favoriteId; // null: «Mi ubicación»
  RoundedLocation? _location;
  MapMode _mode = MapMode.basico;
  bool _ready = false;

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
      _location = location;
    });
  }

  void _selectFavorite(Favorite favorite) =>
      setState(() => _favoriteId = favorite.id);

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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final favoriteId = _favoriteId;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 6, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _PlaceChip(
                        icon: Icons.my_location_rounded,
                        label: 'Mi ubicación',
                        selected: _ready && favoriteId == null,
                        onTap: _ready ? _selectMyLocation : null,
                      ),
                      for (final favorite in _favorites)
                        _PlaceChip(
                          icon: Icons.star_rounded,
                          label: favorite.title,
                          selected: favorite.id == favoriteId,
                          onTap: () => _selectFavorite(favorite),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MapModeMenu(mode: _mode, onChanged: _setMode),
            ],
          ),
        ),
        Expanded(
          child: MapWebView(
            target: _ready
                ? (_mode, favoriteId, favoriteId == null ? _location : null)
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

class _PlaceChip extends StatelessWidget {
  const _PlaceChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _accentCyan : _secondaryTextColor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: onTap == null ? null : (_) => onTap!(),
        showCheckmark: false,
        avatar: Icon(icon, size: 16, color: color),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? _textColor : _secondaryTextColor,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        backgroundColor: _cardBackground,
        selectedColor: _accentCyan.withValues(alpha: 0.18),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

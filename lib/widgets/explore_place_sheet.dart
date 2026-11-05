import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/location_service.dart';
import '../services/place_search.dart';

const _sheetBackground = Color(0xFF0F172A);
const _fieldBackground = Color(0xFF111C33);
const _accentCyan = Color(0xFF4FD0E7);
const _textColor = Color(0xFFF7FAFC);
const _secondaryTextColor = Color(0xFF94A3B8);

/// Máximo que acepta el servidor para el nombre de un favorito.
const int _maxTitleLength = 60;

/// Lo que eligió el usuario: ver el lugar en el mapa o, con [save], además
/// guardarlo en sus favoritos con [name].
class ExploredPlace {
  const ExploredPlace({required this.name, required this.location, required this.save});

  final String name;
  final RoundedLocation location;
  final bool save;
}

/// La hoja para ver otro lugar en el mapa y guardarlo como favorito: se busca
/// por nombre o se escriben las coordenadas, como en la configuración del
/// cielo de antes.
Future<ExploredPlace?> showExplorePlaceSheet(
  BuildContext context, {
  PlaceSearchService? search,
}) {
  return showModalBottomSheet<ExploredPlace>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _sheetBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ExploreSheet(search: search ?? PlaceSearchService()),
  );
}

enum _Mode { search, coordinates }

class _ExploreSheet extends StatefulWidget {
  const _ExploreSheet({required this.search});

  final PlaceSearchService search;

  @override
  State<_ExploreSheet> createState() => _ExploreSheetState();
}

class _ExploreSheetState extends State<_ExploreSheet> {
  final TextEditingController _query = TextEditingController();
  final TextEditingController _lat = TextEditingController();
  final TextEditingController _lon = TextEditingController();
  final TextEditingController _name = TextEditingController();

  _Mode _mode = _Mode.search;
  bool _searching = false;
  List<PlaceResult>? _results;
  String? _error;
  PlaceResult? _chosen;

  // Autocompletar: se espera a que deje de escribir y solo vale la respuesta
  // de lo último que escribió.
  static const _pause = Duration(milliseconds: 400);
  Timer? _debounce;
  int _asked = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _lat.dispose();
    _lon.dispose();
    _name.dispose();
    super.dispose();
  }

  void _typed(String text) {
    _debounce?.cancel();
    if (text.trim().length < 3) {
      _asked++;
      if (_results != null && !_searching) setState(() => _results = null);
      return;
    }
    _debounce = Timer(_pause, () => _suggest(text));
  }

  /// Las sugerencias mientras escribe. Si fallan no se avisa: queda la
  /// búsqueda con Enter.
  Future<void> _suggest(String text) async {
    final ticket = ++_asked;
    try {
      final results = await widget.search.suggest(text);
      if (!mounted || ticket != _asked) return;
      setState(() {
        _results = results;
        _error = null;
      });
    } catch (e) {
      debugPrint('Explorar: el autocompletado falló (${e.runtimeType}).');
    }
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.length < 2 || _searching) return;
    _debounce?.cancel();
    final ticket = ++_asked;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _error = null;
      _chosen = null;
    });
    try {
      final results = await widget.search.search(query);
      if (!mounted || ticket != _asked) return;
      setState(() => _results = results);
    } catch (e) {
      debugPrint('Explorar: la búsqueda falló (${e.runtimeType}).');
      if (mounted) setState(() => _error = 'No se pudo buscar. Revisa la conexión.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _choose(PlaceResult place) {
    setState(() {
      _chosen = place;
      _name.text = place.name.length > _maxTitleLength
          ? place.name.substring(0, _maxTitleLength)
          : place.name;
    });
  }

  void _useCoordinates() {
    final lat = _number(_lat.text);
    final lon = _number(_lon.text);
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
      setState(() => _error = 'La latitud va de -90 a 90 y la longitud de -180 a 180.');
      return;
    }
    FocusScope.of(context).unfocus();
    final location = RoundedLocation(lat, lon);
    setState(() => _error = null);
    _choose(PlaceResult(
      name: '${location.latParam}, ${location.lonParam}',
      detail: 'Coordenadas',
      location: location,
    ));
  }

  /// Acepta la coma decimal del teclado en español.
  static double? _number(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  void _finish({required bool save}) {
    final chosen = _chosen;
    if (chosen == null) return;
    final name = _name.text.trim();
    Navigator.pop(
      context,
      ExploredPlace(
        name: name.isEmpty ? chosen.name : name,
        location: chosen.location,
        save: save,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chosen = _chosen;
    return Padding(
      // El teclado no tapa los campos.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _accentCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.travel_explore_rounded, color: _accentCyan, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Explorar otro lugar',
                          style: TextStyle(color: _textColor, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Mira su cielo en el mapa o guárdalo en tus favoritos.',
                          style: TextStyle(color: _secondaryTextColor, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ModePill(
                      icon: Icons.search_rounded,
                      label: 'Buscar',
                      selected: _mode == _Mode.search,
                      onTap: () => setState(() {
                        _mode = _Mode.search;
                        _error = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ModePill(
                      icon: Icons.explore_outlined,
                      label: 'Coordenadas',
                      selected: _mode == _Mode.coordinates,
                      onTap: () => setState(() {
                        _mode = _Mode.coordinates;
                        _error = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_mode == _Mode.search) ..._searchFields() else ..._coordinateFields(),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
              if (chosen != null) ...[
                const SizedBox(height: 16),
                _ChosenCard(place: chosen, name: _name),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _finish(save: false),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('Ver en el mapa'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _accentCyan,
                          side: BorderSide(color: _accentCyan.withValues(alpha: 0.6)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _finish(save: true),
                        icon: const Icon(Icons.star_rounded, size: 18),
                        label: const Text('Guardar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _accentCyan,
                          foregroundColor: _sheetBackground,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _searchFields() {
    final results = _results;
    return [
      TextField(
        controller: _query,
        autofocus: true,
        textInputAction: TextInputAction.search,
        textCapitalization: TextCapitalization.words,
        onChanged: _typed,
        onSubmitted: (_) => _search(),
        style: const TextStyle(color: _textColor),
        decoration: _decoration(
          hint: 'Ciudad o lugar, ej.: Valparaíso, Chile',
          prefix: Icons.location_city_rounded,
          suffix: _searching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _accentCyan),
                  ),
                )
              : IconButton(
                  tooltip: 'Buscar',
                  icon: const Icon(Icons.arrow_forward_rounded, color: _accentCyan),
                  onPressed: _search,
                ),
        ),
      ),
      if (results != null && results.isEmpty && !_searching) ...[
        const SizedBox(height: 12),
        const Text(
          'No encontramos ese lugar. Prueba con la ciudad y el país.',
          style: TextStyle(color: _secondaryTextColor, fontSize: 13),
        ),
      ],
      if (results != null && results.isNotEmpty) ...[
        const SizedBox(height: 8),
        for (final place in results)
          _ResultTile(
            place: place,
            selected: identical(place, _chosen),
            onTap: () => _choose(place),
          ),
      ],
    ];
  }

  List<Widget> _coordinateFields() {
    const keyboard = TextInputType.numberWithOptions(decimal: true, signed: true);
    final formatters = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'))];
    return [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _lat,
              keyboardType: keyboard,
              inputFormatters: formatters,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: _textColor),
              decoration: _decoration(hint: 'Latitud', prefix: Icons.swap_vert_rounded),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _lon,
              keyboardType: keyboard,
              inputFormatters: formatters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _useCoordinates(),
              style: const TextStyle(color: _textColor),
              decoration: _decoration(hint: 'Longitud', prefix: Icons.swap_horiz_rounded),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _useCoordinates,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Usar estas coordenadas'),
          style: TextButton.styleFrom(foregroundColor: _accentCyan),
        ),
      ),
    ];
  }
}

InputDecoration _decoration({required String hint, required IconData prefix, Widget? suffix}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: _secondaryTextColor.withValues(alpha: 0.6), fontSize: 14),
    prefixIcon: Icon(prefix, color: _secondaryTextColor, size: 20),
    suffixIcon: suffix,
    filled: true,
    fillColor: _fieldBackground,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    enabledBorder: border(_accentCyan.withValues(alpha: 0.2)),
    focusedBorder: border(_accentCyan),
    counterStyle: const TextStyle(color: _secondaryTextColor),
  );
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _accentCyan : _secondaryTextColor;
    return Material(
      color: selected ? _accentCyan.withValues(alpha: 0.12) : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: selected ? _accentCyan : Colors.white24)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.place, required this.selected, required this.onTap});

  final PlaceResult place;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: selected ? _accentCyan.withValues(alpha: 0.1) : _fieldBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? _accentCyan : Colors.white10),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Icon(
                  Icons.place_rounded,
                  size: 20,
                  color: selected ? _accentCyan : _secondaryTextColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(color: _textColor, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      if (place.detail.isNotEmpty && place.detail != place.name)
                        Text(
                          place.detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _secondaryTextColor, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (selected) const Icon(Icons.check_circle_rounded, color: _accentCyan, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El lugar elegido, con su nombre para el favorito.
class _ChosenCard extends StatelessWidget {
  const _ChosenCard({required this.place, required this.name});

  final PlaceResult place;
  final TextEditingController name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _accentCyan.withValues(alpha: 0.10),
            const Color(0xFF8B5CF6).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accentCyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.my_location_rounded, color: _accentCyan, size: 16),
              const SizedBox(width: 6),
              Text(
                '${place.location.latParam} · ${place.location.lonParam}',
                style: const TextStyle(color: _secondaryTextColor, fontSize: 12.5),
              ),
            ],
          ),
          TextField(
            controller: name,
            maxLength: _maxTitleLength,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: _textColor, fontSize: 15, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              labelText: 'Nombre del lugar',
              labelStyle: TextStyle(color: _secondaryTextColor),
              counterStyle: TextStyle(color: _secondaryTextColor),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _accentCyan),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

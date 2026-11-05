import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const _accentCyan = Color(0xFF4FD0E7);
const _secondaryTextColor = Color(0xFF94A3B8);

/// El mini mapa para elegir un punto, con los mosaicos de OpenStreetMap del
/// portal: al tocarlo se marca y se avisa con [onPicked]. Sin [point] se ve el
/// mundo entero.
class CoordinatePickerMap extends StatefulWidget {
  const CoordinatePickerMap({super.key, this.point, required this.onPicked});

  final LatLng? point;
  final ValueChanged<LatLng> onPicked;

  @override
  State<CoordinatePickerMap> createState() => _CoordinatePickerMapState();
}

class _CoordinatePickerMapState extends State<CoordinatePickerMap> {
  final MapController _map = MapController();
  bool _ready = false;

  @override
  void didUpdateWidget(CoordinatePickerMap old) {
    super.didUpdateWidget(old);
    // Coordenadas escritas a mano: el mapa va hasta ellas.
    final p = widget.point;
    if (_ready && p != null && p != old.point && !_visible(p)) {
      _map.move(p, _map.camera.zoom < 6 ? 6 : _map.camera.zoom);
    }
  }

  bool _visible(LatLng p) => _map.camera.visibleBounds.contains(p);

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.point;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          border: Border.all(color: _accentCyan.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: point ?? const LatLng(10, -40),
            initialZoom: point == null ? 1.5 : 6,
            minZoom: 1,
            maxZoom: 16,
            backgroundColor: const Color(0xFF111C33),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () => _ready = true,
            onTap: (_, p) => widget.onPicked(p),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              // La política de los mosaicos de OSM pide identificar la app.
              userAgentPackageName: 'com.windowsdemeter',
              tileProvider: NetworkTileProvider(silenceExceptions: true),
            ),
            if (point != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 36,
                    height: 36,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.place_rounded, color: _accentCyan, size: 36),
                  ),
                ],
              ),
            const Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xB30F172A)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    child: Text(
                      '© OpenStreetMap',
                      style: TextStyle(color: _secondaryTextColor, fontSize: 9.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

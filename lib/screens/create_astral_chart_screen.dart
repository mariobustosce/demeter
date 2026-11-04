import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../config/zonas_iana.dart';
import '../models/carta.dart';
import '../services/api_client.dart';
import '../services/astral_chart_service.dart';

const backgroundColor = Color(0xFF0A0A0F);
const accentCyan = Color(0xFF4FD0E7);
const accentPurple = Color(0xFF8B5CF6);
const cardBackground = Color(0xEF0F172A);
const textColor = Color(0xFFF7FAFC);
const secondaryTextColor = Color(0xFF94A3B8);

class LocationSuggestion {
  final String display;
  final double lat;
  final double lon;

  LocationSuggestion({required this.display, required this.lat, required this.lon});
}

class CreateAstralChartScreen extends StatefulWidget {
  const CreateAstralChartScreen({super.key, this.service});

  /// Para los tests; por defecto, el de [ApiClient.instance].
  final AstralChartService? service;

  @override
  State<CreateAstralChartScreen> createState() =>
      _CreateAstralChartScreenState();
}

class _CreateAstralChartScreenState extends State<CreateAstralChartScreen> {
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _searchController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();

  late final AstralChartService _chartService =
      widget.service ?? AstralChartService();
  bool _useManualLocation = true;
  bool _isLoading = false;

  // Zona del lugar de nacimiento: la sugiere el servidor. Solo si el usuario
  // la cambia a mano se manda `timezone` en el alta.
  ZonaLugar? _zonaLugar;
  String? _zonaManual;
  bool _zonaCargando = false;
  bool _zonaFallo = false;
  Timer? _zonaTimer;
  int _zonaPedido = 0;

  @override
  void dispose() {
    _zonaTimer?.cancel();
    _titleController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _searchController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  ({double lat, double lon})? get _punto {
    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());
    if (lat == null || lon == null) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
    return (lat: lat, lon: lon);
  }

  /// Pide la zona del lugar al fijar el lugar o cambiar la fecha o la hora.
  void _programarZona() {
    _zonaTimer?.cancel();
    if (_punto == null) {
      _zonaPedido++;
      setState(() {
        _zonaLugar = null;
        _zonaCargando = false;
        _zonaFallo = false;
      });
      return;
    }
    setState(() => _zonaCargando = true);
    _zonaTimer = Timer(const Duration(milliseconds: 500), _pedirZona);
  }

  Future<void> _pedirZona() async {
    final punto = _punto;
    if (punto == null) return;
    final pedido = ++_zonaPedido;
    try {
      final zona = await _chartService.zona(
        lat: punto.lat,
        lon: punto.lon,
        fecha: _dateController.text,
        hora: _timeController.text,
      );
      // Una respuesta vieja no pisa a la última.
      if (!mounted || pedido != _zonaPedido) return;
      setState(() {
        _zonaLugar = zona;
        _zonaCargando = false;
        _zonaFallo = false;
      });
    } catch (e) {
      if (!mounted || pedido != _zonaPedido) return;
      // Sin lugar ni coordenadas en el log. No bloquea: el servidor la
      // resuelve al guardar.
      debugPrint('Zona del lugar falló (${e.runtimeType}).');
      setState(() {
        _zonaLugar = null;
        _zonaCargando = false;
        _zonaFallo = true;
      });
    }
  }

  Future<void> _cambiarZona() async {
    final elegida = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ZonaPicker(actual: _zonaManual ?? _zonaLugar?.timezone),
    );
    if (elegida == null || !mounted) return;
    setState(() {
      // Elegir la misma que sugiere el lugar es no haberla cambiado.
      _zonaManual = elegida == _zonaLugar?.timezone ? null : elegida;
    });
  }

  Future<List<LocationSuggestion>> _searchLocations(String query) async {
    if (query.length < 3) return []; // Minimum 3 characters to search

    // Uri.https codifica la búsqueda; la política de Nominatim pide un
    // User-Agent que identifique la app.
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'json',
      'q': query,
      'limit': '5',
    });
    try {
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': kNominatimUserAgent,
          'Accept': 'application/json',
        },
      ).timeout(kRequestTimeout);
      if (response.statusCode != 200) {
        debugPrint('Nominatim → ${response.statusCode}');
        return [];
      }
      final data = json.decode(response.body) as List;
      return data.map((item) => LocationSuggestion(
        display: item['display_name'] ?? 'Unknown',
        lat: double.tryParse(item['lat'] ?? '0') ?? 0.0,
        lon: double.tryParse(item['lon'] ?? '0') ?? 0.0,
      )).toList();
    } catch (e) {
      // Sin la búsqueda ni la URL: pueden decir dónde nació alguien.
      debugPrint('Nominatim falló (${e.runtimeType}).');
      return [];
    }
  }

  void _submit() async {
    if (_titleController.text.isEmpty ||
        _dateController.text.isEmpty ||
        _timeController.text.isEmpty ||
        _latController.text.isEmpty ||
        _lonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final double? lat = double.tryParse(_latController.text);
    final double? lon = double.tryParse(_lonController.text);

    if (lat == null || lon == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Latitud o longitud inválida')),
      );
      return;
    }

    final response = await _chartService.createChart(
      title: _titleController.text,
      birthDate: _dateController.text, // Asegúrate de que el formato sea yyyy-mm-dd
      birthTime: _timeController.text, // Asegúrate de que el formato sea HH:mm
      birthLat: lat,
      birthLon: lon,
      // Sin cambio manual va sin zona: el servidor usa la del lugar.
      timezone: _zonaManual,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // El servidor ya lo redacta con la palabra «firmamento».
          content: Text(apiMessage(response['data']) ?? '✨ Firmamento creado'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // Volver atrás a la lista
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Error desconocido'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text('🌟', style: TextStyle(fontSize: 28)),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Nuevo firmamento',
                    style: TextStyle(
                      color: accentCyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Tu carta astral: la foto de los astros del cielo en el momento y lugar de tu nacimiento',
              style: TextStyle(color: secondaryTextColor, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Form Content
            _buildFormSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('✨', 'Título del firmamento'),
          _buildTextField(
            controller: _titleController,
            hintText: 'Ej: Mi Carta Natal, Carta del Alma Gemela, etc.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Dale un nombre personal a tu firmamento',
            style: TextStyle(color: secondaryTextColor, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // Date & Time
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('📅', 'Fecha de Nacimiento'),
                    _buildTextField(
                      controller: _dateController,
                      hintText: 'yyyy-mm-dd',
                      suffixIcon: Icons.calendar_today,
                      readOnly: true,
                      backgroundColor: const Color(0xFF17212F),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)), // 20 años atrás
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: accentCyan,
                                  onPrimary: Color.fromARGB(255, 97, 35, 112),
                                  surface: Color.fromARGB(237, 95, 131, 185),
                                  onSurface: textColor,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (date != null) {
                          // Format: YYYY-MM-DD
                          final month = date.month.toString().padLeft(2, '0');
                          final day = date.day.toString().padLeft(2, '0');
                          _dateController.text = "${date.year}-$month-$day";
                          _programarZona();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('⏰', 'Hora de Nacimiento'),
                    _buildTextField(
                      controller: _timeController,
                      hintText: 'HH:mm',
                      suffixIcon: Icons.access_time,
                      readOnly: true,
                      backgroundColor: const Color(0xFF17212F),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: const TimeOfDay(hour: 12, minute: 0),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: accentCyan,
                                  onPrimary: Colors.black,
                                  surface: cardBackground,
                                  onSurface: textColor,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (time != null) {
                          // Format: HH:mm
                          final hour = time.hour.toString().padLeft(2, '0');
                          final minute = time.minute.toString().padLeft(2, '0');
                          _timeController.text = "$hour:$minute";
                          _programarZona();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Location Toggle
          Container(
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _useManualLocation = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _useManualLocation
                            ? accentCyan.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Ingreso Manual',
                          style: TextStyle(
                            color: _useManualLocation
                                ? accentCyan
                                : secondaryTextColor,
                            fontWeight: _useManualLocation
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _useManualLocation = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_useManualLocation
                            ? accentCyan.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Mapa Interactivo',
                          style: TextStyle(
                            color: !_useManualLocation
                                ? accentCyan
                                : secondaryTextColor,
                            fontWeight: !_useManualLocation
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Conditional Location Inputs
          if (_useManualLocation) ...[
            _buildLabel('📍', 'Ciudad o Dirección'),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TypeAheadField<LocationSuggestion>(
                controller: _searchController,
                builder: (context, controller, focusNode) => TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: const TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ej. Madrid, España...',
                    hintStyle: const TextStyle(color: secondaryTextColor, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                suggestionsCallback: _searchLocations,
                // Nominatim admite como máximo una búsqueda por segundo.
                debounceDuration: const Duration(seconds: 1),
                itemBuilder: (context, suggestion) => Container(
                  color: cardBackground,
                  child: ListTile(
                    title: Text(
                      suggestion.display,
                      style: const TextStyle(color: textColor, fontSize: 14),
                    ),
                  ),
                ),
                onSelected: (suggestion) {
                  _searchController.text = suggestion.display;
                  _latController.text = suggestion.lat.toStringAsFixed(4);
                  _lonController.text = suggestion.lon.toStringAsFixed(4);
                  _programarZona();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Coordenadas: ${suggestion.lat}, ${suggestion.lon}'),
                      backgroundColor: Colors.green.shade700,
                    ),
                  );
                },
                decorationBuilder: (context, child) => Container(
                  decoration: BoxDecoration(
                    color: cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: child,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Escribe la dirección y selecciona una sugerencia para rellenar automáticamente las coordenadas',
              style: TextStyle(color: secondaryTextColor, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('🌍', 'Latitud'),
                      _buildTextField(
                        controller: _latController,
                        hintText: '-33.4489',
                        onChanged: (_) => _programarZona(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('🌍', 'Longitud'),
                      _buildTextField(
                        controller: _lonController,
                        hintText: '-70.6693',
                        onChanged: (_) => _programarZona(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🗺️', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 8),
                      Text(
                        'Seleccionar Ubicación con el Mapa',
                        style: TextStyle(
                          color: accentCyan,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      backgroundColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Abrir Mapa interactivo',
                      style: TextStyle(
                          color: accentCyan, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Usa el mapa para encontrar tus coordenadas exactas de forma visual.',
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 24),

          // Zona horaria: la del lugar, nunca la del teléfono ni «UTC».
          _buildLabel('🕒', 'Zona horaria'),
          _buildZona(),
          const SizedBox(height: 32),

          // Generate Button
          Center(
            child: _isLoading
                ? const CircularProgressIndicator(color: accentCyan)
                : Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                        colors: [accentCyan, accentPurple],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Text('✨', style: TextStyle(fontSize: 18)),
                      label: const Text(
                        'Crear firmamento',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: accentCyan,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    IconData? suffixIcon,
    bool readOnly = false,
    VoidCallback? onTap,
    VoidCallback? onSuffixTap,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
    bool isLoading = false,
    Color backgroundColor = const Color(0xFF0F172A),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: textColor, fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: secondaryTextColor, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: isLoading
              ? const Padding(
                  padding: EdgeInsets.only(right: 12.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(accentCyan),
                    ),
                  ),
                )
              : suffixIcon != null
                  ? onSuffixTap != null
                      ? IconButton(
                          onPressed: onSuffixTap,
                          icon: Icon(suffixIcon, color: secondaryTextColor, size: 20),
                        )
                      : Icon(suffixIcon, color: secondaryTextColor, size: 20)
                  : null,
        ),
      ),
    );
  }

  /// La zona del lugar bajo el formulario, con «Cambiar zona» discreto.
  Widget _buildZona() {
    const estilo = TextStyle(color: textColor, fontSize: 13, height: 1.35);
    const tenue = TextStyle(color: secondaryTextColor, fontSize: 12, height: 1.35);

    final Widget linea;
    if (_zonaManual != null) {
      linea = Text('$_zonaManual · elegida a mano', style: estilo);
    } else if (_zonaCargando) {
      linea = const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: accentCyan),
          ),
          SizedBox(width: 8),
          Flexible(child: Text('Buscando la zona del lugar…', style: tenue)),
        ],
      );
    } else if (_zonaLugar != null) {
      final z = _zonaLugar!;
      final cuando = _dateController.text.isEmpty ? 'hoy rige' : 'ese día regía';
      linea = Text(
        '${z.timezone} · $cuando ${z.rotulo}'
        '${z.horarioVerano ? ' · horario de verano' : ''}',
        style: estilo,
      );
    } else if (_zonaFallo) {
      linea = const Text(
        'No se pudo consultar la zona. Se usará la del lugar al guardar.',
        style: tenue,
      );
    } else {
      linea = const Text(
        'Se usará la zona del lugar de nacimiento.',
        style: tenue,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyedSubtree(key: const Key('zona-linea'), child: linea),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              children: [
                if (_zonaManual != null)
                  TextButton(
                    onPressed: () => setState(() => _zonaManual = null),
                    style: TextButton.styleFrom(foregroundColor: secondaryTextColor),
                    child: const Text('Usar la del lugar', style: TextStyle(fontSize: 12)),
                  ),
                TextButton(
                  onPressed: _cambiarZona,
                  style: TextButton.styleFrom(foregroundColor: accentCyan),
                  child: const Text('Cambiar zona', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja para elegir otra zona IANA: el caso raro de una hora anotada en otra
/// zona. Devuelve el nombre elegido.
class _ZonaPicker extends StatefulWidget {
  const _ZonaPicker({this.actual});

  final String? actual;

  @override
  State<_ZonaPicker> createState() => _ZonaPickerState();
}

class _ZonaPickerState extends State<_ZonaPicker> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final f = _filtro.toLowerCase().replaceAll(' ', '_');
    final zonas = [
      for (final z in kZonasIana)
        if (f.isEmpty || z.toLowerCase().contains(f)) z,
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text(
                  'Cambiar zona',
                  style: TextStyle(color: accentCyan, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Solo si la hora se anotó en otra zona que la del lugar de nacimiento.',
                  style: TextStyle(color: secondaryTextColor, fontSize: 12, height: 1.35),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: TextField(
                    autofocus: false,
                    onChanged: (v) => setState(() => _filtro = v.trim()),
                    style: const TextStyle(color: textColor, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Buscar, p. ej. Madrid',
                      hintStyle: TextStyle(color: secondaryTextColor, fontSize: 14),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search, color: secondaryTextColor, size: 20),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: zonas.length,
                  itemBuilder: (context, i) {
                    final z = zonas[i];
                    final actual = z == widget.actual;
                    return ListTile(
                      dense: true,
                      title: Text(
                        z,
                        style: TextStyle(
                          color: actual ? accentCyan : textColor,
                          fontSize: 14,
                          fontWeight: actual ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: actual
                          ? const Icon(Icons.check, color: accentCyan, size: 18)
                          : null,
                      onTap: () => Navigator.pop(context, z),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

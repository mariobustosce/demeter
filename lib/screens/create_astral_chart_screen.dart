import 'package:flutter/material.dart';
import '../services/astral_chart_service.dart';
import '../services/sky_service.dart';

const backgroundColor = Color(0xFF0A0A0F);
const accentCyan = Color(0xFF4FD0E7);
const accentPurple = Color(0xFF8B5CF6);
const cardBackground = Color(0xEF0F172A);
const textColor = Color(0xFFF7FAFC);
const secondaryTextColor = Color(0xFF94A3B8);

class CreateAstralChartScreen extends StatefulWidget {
  const CreateAstralChartScreen({super.key});

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

  final AstralChartService _chartService = AstralChartService();
  final SkyService _skyService = SkyService();
  String _selectedTimezone = 'UTC';
  bool _useManualLocation = true;
  bool _isLoading = false;
  bool _isSearchingLocation = false;

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
      timezone: _selectedTimezone,
    );

    setState(() {
      _isLoading = false;
    });

    if (response['success']) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Carta astral creada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // Volver atrás a la lista
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Error desconocido'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearchingLocation = true;
    });

    final result = await _skyService.searchLocation(query);

    if (!mounted) return;
    setState(() {
      _isSearchingLocation = false;
    });

    if (result != null) {
      setState(() {
        _latController.text = result['lat'].toString();
        _lonController.text = result['lon'].toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Coordenadas encontradas: ${result['lat']}, ${result['lon']}'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación no encontrada')),
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
                    'Generador de Carta Astral',
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
              'Descubre tu mapa celestial personal basado en tu fecha, hora y lugar de nacimiento',
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
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('✨', 'Título de la Carta Astral'),
          _buildTextField(
            controller: _titleController,
            hintText: 'Ej: Mi Carta Natal, Carta del Alma Gemela, etc.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Dale un nombre personal a tu carta astral',
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
                                  onPrimary: Colors.black,
                                  surface: cardBackground,
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
              border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                            ? accentCyan.withOpacity(0.2)
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
                            ? accentCyan.withOpacity(0.2)
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
            _buildTextField(
              controller: _searchController,
              hintText: 'Ej. Madrid, España...',
              suffixIcon: Icons.search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchLocation(),
              onSuffixTap: _searchLocation,
              isLoading: _isSearchingLocation,
            ),
            const SizedBox(height: 8),
            const Text(
              'Escribe el lugar de nacimiento para rellenar automáticamente las coordenadas',
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
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
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

          // Timezone
          _buildLabel('🕒', 'Zona Horaria'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTimezone,
                isExpanded: true,
                dropdownColor: cardBackground,
                style: const TextStyle(color: textColor, fontSize: 14),
                icon: const Icon(Icons.keyboard_arrow_down, color: secondaryTextColor),
                items: ['UTC', 'UTC-4 (Chile)', 'UTC-3 (Argentina)']
                    .map((e) => DropdownMenuItem(
                          value: e.split(' ')[0], // Solo el valor para la prueba 'UTC',...
                          child: Text(e),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    if (val != null) _selectedTimezone = val;
                  });
                },
              ),
            ),
          ),
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
                        'Generar Carta Astral',
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
    bool isLoading = false,
    Color backgroundColor = const Color(0xFF0F172A),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
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
}

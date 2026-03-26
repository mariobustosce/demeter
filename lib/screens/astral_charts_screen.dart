import 'package:flutter/material.dart';
import '../services/astral_chart_service.dart';
import 'create_astral_chart_screen.dart';

const backgroundColor = Color(0xFF0A0A0F);
const accentCyan = Color(0xFF4FD0E7);
const accentPurple = Color(0xFF8B5CF6);
const cardBackground = Color(0xEF0F172A);
const textColor = Color(0xFFF7FAFC);
const secondaryTextColor = Color(0xFF94A3B8);

class AstralChartsScreen extends StatefulWidget {
  const AstralChartsScreen({super.key});

  @override
  State<AstralChartsScreen> createState() => _AstralChartsScreenState();
}

class _AstralChartsScreenState extends State<AstralChartsScreen> {
  final AstralChartService _chartService = AstralChartService();
  List<dynamic> _charts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCharts();
  }

  Future<void> _loadCharts() async {
    setState(() {
      _isLoading = true;
    });
    
    final charts = await _chartService.getUserCharts();
    
    if (mounted) {
      setState(() {
        _charts = charts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Text('🌟', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text(
              'Mis Cartas Astrales',
              style: TextStyle(
                color: accentCyan,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Administra y explora tus cartas astrales personalizadas',
              style: TextStyle(
                color: textColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: accentCyan))
                  : _charts.isEmpty 
                      ? _buildEmptyState() 
                      : _buildChartsList(),
            ),
          ],
        ),
      ),
      floatingActionButton: _charts.isNotEmpty && !_isLoading
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateAstralChartScreen(),
                  ),
                );
                _loadCharts();
              },
              backgroundColor: accentCyan,
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.05),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.purple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.nights_stay,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No tienes cartas astrales aún',
              style: TextStyle(
                color: accentCyan,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Crea tu primera carta astral para descubrir tu\nmapa celestial personal basado en tu fecha,\nhora y lugar de nacimiento.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [accentCyan, accentPurple],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateAstralChartScreen(),
                    ),
                  );
                  _loadCharts(); // Refrescar al volver
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Text('🌟', style: TextStyle(fontSize: 18)),
                label: const Text(
                  'Crear mi Primera Carta Astral',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to format date from yyyy-mm-dd to dd/mm/yyyy
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '--/--/----';
    try {
      final dateOnly = dateStr.split('T')[0].split(' ')[0];
      final parts = dateOnly.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    } catch (_) {}
    return dateStr;
  }

  // Helper function to format time removing seconds if present (HH:mm:ss to HH:mm)
  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--:--';
    try {
      final timeOnly = timeStr.contains('T') ? timeStr.split('T').last.split('Z')[0] : timeStr;
      final parts = timeOnly.split(':');
      if (parts.length >= 2) {
        return '${parts[0]}:${parts[1]}';
      }
    } catch (_) {}
    return timeStr;
  }

  // Helper function to format coordinates slightly shorter
  String _formatCoord(dynamic coord) {
    if (coord == null) return '';
    if (coord is num) return coord.toStringAsFixed(2);
    if (coord is String) {
      final numVal = double.tryParse(coord);
      if (numVal != null) return numVal.toStringAsFixed(2);
    }
    return coord.toString();
  }

  Widget _buildChartsList() {
    return ListView.builder(
      itemCount: _charts.length,
      itemBuilder: (context, index) {
        final chart = _charts[index];
        return Card(
          color: const Color(0xFF15151D), // Un fondo oscuro elegante para la carta
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentPurple.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getSignEmoji(chart['sun_sign']),
                        style: const TextStyle(fontSize: 22, color: accentPurple),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8.0,
                            runSpacing: 6.0,
                            children: [
                              Text(
                                chart['titulo'] ?? chart['title'] ?? 'Carta Astral',
                                style: const TextStyle(
                                  color: accentCyan,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today, size: 12, color: secondaryTextColor),
                                    const SizedBox(width: 4),
                                    Text('${_formatDate(chart['birth_date'])} ${_formatTime(chart['birth_time'])}', 
                                      style: const TextStyle(color: secondaryTextColor, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.public, size: 12, color: accentCyan),
                                    const SizedBox(width: 4),
                                    Text('${_formatCoord(chart['birth_lat'])}°, ${_formatCoord(chart['birth_lon'])}°',
                                      style: const TextStyle(color: secondaryTextColor, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Signo: ${chart['sun_sign'] ?? 'Aries'}',
                            style: TextStyle(
                              color: Colors.red[300],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),

                // BODY: Planetas y Rueda
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Planetas Principales',
                              style: TextStyle(color: accentPurple, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            children: _buildMockPlanets(),
                          ),
                          const SizedBox(height: 20),
                          const Text('Puntos Importantes',
                              style: TextStyle(color: accentPurple, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(
                            children: const [
                              Text('ASC: ', style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                              Text('330.0°', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              SizedBox(width: 24),
                              Text('MC: ', style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                              Text('60.0°', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text('Creada: ${chart['created_at'] != null ? chart['created_at'].toString().split('T')[0] : 'Hoy'}',
                              style: const TextStyle(color: secondaryTextColor, fontSize: 11)),
                          Text('Zona: ${chart['timezone'] ?? 'UTC'}',
                              style: const TextStyle(color: secondaryTextColor, fontSize: 11)),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                            color: Colors.black.withOpacity(0.2),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Marcas del reloj
                              ...List.generate(12, (i) {
                                return Transform.rotate(
                                  angle: i * 3.14159 / 6,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Container(
                                      width: 1,
                                      height: 6,
                                      color: Colors.white24,
                                    ),
                                  ),
                                );
                              }),
                              // Iconos simulados por dentro
                              const Positioned(top: 25, left: 20, child: Text('🌞', style: TextStyle(fontSize: 10))),
                              const Positioned(bottom: 30, right: 15, child: Text('🌙', style: TextStyle(fontSize: 10))),
                              const Positioned(top: 40, right: 20, child: Text('ASC', style: TextStyle(color: accentCyan, fontSize: 8, fontWeight: FontWeight.bold))),
                              const Positioned(bottom: 25, left: 30, child: Text('MC', style: TextStyle(color: accentPurple, fontSize: 8, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // FOOTER BUTTONS
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Navegar a los detalles
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accentCyan,
                          side: BorderSide(color: accentCyan.withOpacity(0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.remove_red_eye, size: 18),
                        label: const Text('Ver en Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.2)),
                      ),
                      child: IconButton(
                        onPressed: () {
                          // TODO: Implementar eliminación
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getSignEmoji(String? sign) {
    if (sign == null) return '♈';
    final s = sign.toLowerCase();
    if (s.contains('tauro')) return '♉';
    if (s.contains('gemini') || s.contains('géminis')) return '♊';
    if (s.contains('cancer') || s.contains('cáncer')) return '♋';
    if (s.contains('leo')) return '♌';
    if (s.contains('virgo')) return '♍';
    if (s.contains('libra')) return '♎';
    if (s.contains('escorpio') || s.contains('scorpio')) return '♏';
    if (s.contains('sagitario') || s.contains('sagittarius')) return '♐';
    if (s.contains('capricornio') || s.contains('capricorn')) return '♑';
    if (s.contains('acuario') || s.contains('aquarius')) return '♒';
    if (s.contains('piscis') || s.contains('pisces')) return '♓';
    return '♈'; // Aries por defecto
  }

  List<Widget> _buildMockPlanets() {
    return [
      _planetItem('🌞', '304.0°', Colors.orange),
      _planetItem('🌙', '46.0°', Colors.white),
      _planetItem('♂️', '225.0°', Colors.redAccent),
      _planetItem('♅', '338.0°', Colors.tealAccent),
      _planetItem('☿️', '201.0°', Colors.orangeAccent),
      _planetItem('♃', '329.0°', Colors.blueAccent),
    ];
  }

  Widget _planetItem(String emoji, String degree, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: TextStyle(fontSize: 14, color: color)),
        const SizedBox(width: 6),
        Text(
          degree,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

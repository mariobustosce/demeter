import 'package:flutter/material.dart';
import '../models/carta.dart';
import '../services/astral_chart_service.dart';
import '../widgets/firmamento/tablas.dart';
import 'create_astral_chart_screen.dart';

const backgroundColor = Color(0xFF0A0A0F);
const accentCyan = Color(0xFF4FD0E7);
const accentPurple = Color(0xFF8B5CF6);
const cardBackground = Color(0xEF0F172A);
const textColor = Color(0xFFF7FAFC);
const secondaryTextColor = Color(0xFF94A3B8);

/// Firmamentos: las cartas astrales del usuario.
class AstralChartsScreen extends StatefulWidget {
  const AstralChartsScreen({super.key, this.service});

  /// Para los tests; por defecto, el de [ApiClient.instance].
  final AstralChartService? service;

  @override
  State<AstralChartsScreen> createState() => _AstralChartsScreenState();
}

class _AstralChartsScreenState extends State<AstralChartsScreen> {
  late final AstralChartService _chartService =
      widget.service ?? AstralChartService();
  List<Carta> _charts = [];
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
        _charts = [for (final c in charts) ?Carta.fromJson(c)];
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateAstralChartScreen(service: widget.service),
      ),
    );
    _loadCharts(); // Refrescar al volver
  }

  Future<void> _confirmDelete(BuildContext context, Carta chart) async {
    final chartTitle = chart.titulo.isEmpty ? 'este firmamento' : chart.titulo;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 12),
            Text('Confirmar Eliminación', style: TextStyle(color: textColor)),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar "$chartTitle"?\n\nEsta acción no se puede deshacer.',
          style: const TextStyle(color: secondaryTextColor, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: secondaryTextColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    // Mostrar indicador de carga
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Eliminando firmamento...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    final result = await _chartService.deleteChart(chart.id);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // El mensaje lo redacta el servidor.
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Firmamento eliminado'),
          backgroundColor: Colors.green,
        ),
      );
      _loadCharts(); // Recargar la lista
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Error al eliminar el firmamento'),
          backgroundColor: Colors.redAccent,
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
        title: const Row(
          children: [
            Text('🌟', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text(
              'Firmamentos',
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
              'Tus cartas astrales: fotos de los astros del cielo en un momento y lugar',
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
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              backgroundColor: accentCyan,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text(
                'Nuevo firmamento',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
            color: Colors.white.withValues(alpha: 0.05),
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
              'Aún no tienes firmamentos',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accentCyan,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Crea tu primer firmamento: la foto de los astros\ndel cielo en el momento y lugar de tu nacimiento.',
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
                onPressed: _openCreate,
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
                  'Nuevo firmamento',
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

  // De yyyy-mm-dd a dd/mm/yyyy.
  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
    return dateStr.isEmpty ? '--/--/----' : dateStr;
  }

  String _formatCoord(double? coord) => coord?.toStringAsFixed(2) ?? '';

  Widget _chip(IconData icon, String text, {Color iconColor = accentCyan}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(color: secondaryTextColor, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsList() {
    return ListView.builder(
      // Deja libre el botón flotante al final.
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _charts.length,
      itemBuilder: (context, index) {
        final chart = _charts[index];
        final signo = chart.sunSign == null ? null : kSignos[chart.sunSign!];
        return Card(
          color: const Color(0xFF15151D), // Un fondo oscuro elegante para la carta
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Signo solar, del grado real.
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accentPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    signo == null ? '☉' : glifoTexto(signo.glifo),
                    style: TextStyle(
                      fontSize: 22,
                      color: signo?.color ?? accentPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chart.titulo.isEmpty ? 'Firmamento' : chart.titulo,
                        style: const TextStyle(
                          color: Color.fromARGB(255, 239, 242, 243),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (signo != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Sol en ${signo.nombre}',
                          style: TextStyle(
                            color: signo.color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 6.0,
                        children: [
                          _chip(
                            Icons.calendar_today,
                            '${_formatDate(chart.birthDate)} '
                            '${chart.birthTime.isEmpty ? '--:--' : chart.birthTime}',
                          ),
                          if (chart.lat != null && chart.lon != null)
                            _chip(
                              Icons.public,
                              '${_formatCoord(chart.lat)}°, ${_formatCoord(chart.lon)}°',
                            ),
                          if (chart.timezone != null)
                            _chip(Icons.schedule, chart.timezone!),
                          if (chart.tzRevisar) const _RevisarZona(),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: () => _confirmDelete(context, chart),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Distintivo discreto: la carta se guardó con una zona que no es la del
/// lugar y ese día regía otro desfase.
class _RevisarZona extends StatelessWidget {
  const _RevisarZona();

  @override
  Widget build(BuildContext context) {
    const ambar = Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ambar.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ambar.withValues(alpha: 0.4)),
      ),
      child: const Text(
        '🕐 revisar zona',
        style: TextStyle(color: ambar, fontSize: 12),
      ),
    );
  }
}

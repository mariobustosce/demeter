import 'package:flutter/material.dart';
import '../services/oracle_service.dart';
import 'new_consultation_screen.dart';
import 'compatibility_screen.dart';
import 'consultation_detail_screen.dart';

const backgroundColor = Color(0xFF0A0A0F);
const accentCyan = Color(0xFF4FD0E7);
const accentPurple = Color(0xFF8B5CF6);
const cardBackground = Color(0xEF0F172A);
const textColor = Color(0xFFF7FAFC);
const secondaryTextColor = Color(0xFF94A3B8);

class OracleConsultationsScreen extends StatefulWidget {
  const OracleConsultationsScreen({super.key});

  @override
  State<OracleConsultationsScreen> createState() => _OracleConsultationsScreenState();
}

class _OracleConsultationsScreenState extends State<OracleConsultationsScreen> {
  final OracleService _oracleService = OracleService();
  List<dynamic> _consultations = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadConsultations();
  }

  Future<void> _loadConsultations() async {
    setState(() {
      _isLoading = true;
    });
    
    final historial = await _oracleService.getHistorialConsultas();
    
    if (mounted) {
      setState(() {
        _consultations = historial;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmDelete(BuildContext context, dynamic consultation) async {
    final consultationId = consultation['id'];
    final pregunta = consultation['pregunta'] ?? 'esta consulta';

    if (consultationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se pudo identificar la consulta'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

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
          '¿Estás seguro de que deseas eliminar la consulta "$pregunta"?\n\nEsta acción no se puede deshacer.',
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
            Text('Eliminando consulta...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    final result = await _oracleService.deleteConsultation(consultationId);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Consulta eliminada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      _loadConsultations();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Error al eliminar la consulta'),
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
        toolbarHeight: 80,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.menu_book, color: accentCyan, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Historial de Consultas',
                  style: TextStyle(
                    color: accentPurple, // O el color de la imagen (morado claro)
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(left: 48.0, top: 4),
              child: Text(
                'Tus conversaciones con las estrellas guiadas por la IA',
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF15151D), // Fondo estilo tarjeta
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: accentCyan))
              : _consultations.isEmpty 
                  ? _buildEmptyState() 
                  : _buildConsultationsList(),
        ),
      ),      floatingActionButton: _consultations.isNotEmpty && !_isLoading
          ? FloatingActionButton(
              onPressed: _showFabOptions,
              backgroundColor: accentCyan,
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Icon(
              Icons.menu_book,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aún no hay registros',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tus consultas a las estrellas se guardarán aquí para\nque puedas revisarlas cuando lo desees.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              // TODO: Abrir el modal o pantalla de nueva consulta (Imagen 2)
              _showNewConsultationMenu();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentCyan,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'REALIZAR PRIMERA CONSULTA',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Fecha desconocida';
    try {
      final dateOnly = dateStr.split('T')[0];
      final parts = dateOnly.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    } catch (_) {}
    return dateStr;
  }

  Widget _buildConsultationsList() {
    return RefreshIndicator(
      color: accentCyan,
      backgroundColor: backgroundColor,
      onRefresh: _loadConsultations,
      child: ListView.builder(
        itemCount: _consultations.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final item = _consultations[index];
          final pregunta = item['pregunta'] ?? 'Sin pregunta';
          final respuesta = item['respuesta'] ?? item['response'] ?? 'Sin respuesta';
          final fecha = _formatDate(item['created_at']);
          final tipo = item['nivel_contexto'] ?? 'basico';
          
          Color tipoColor = Colors.white;
          String tipoEmoji = '💫';
          
          if (tipo == 'intermedio') {
            tipoColor = accentCyan;
            tipoEmoji = '✨';
          } else if (tipo == 'premium') {
            tipoColor = Colors.amber;
            tipoEmoji = '🌟';
          }

          return Card(
            color: Colors.black.withOpacity(0.3),
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
            child: ExpansionTile(
              iconColor: accentCyan,
              collapsedIconColor: secondaryTextColor,
              title: Text(
                pregunta,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: secondaryTextColor.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      fecha,
                      style: TextStyle(color: secondaryTextColor.withOpacity(0.7), fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      '$tipoEmoji ${tipo.toString().toUpperCase()}',
                      style: TextStyle(color: tipoColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentPurple.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.auto_awesome, color: accentPurple, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              respuesta,
                              style: const TextStyle(
                                color: textColor,
                                fontSize: 14,
                                height: 1.5,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ConsultationDetailScreen(consultation: item),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: accentCyan,
                                side: BorderSide(color: accentCyan.withOpacity(0.3)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.visibility, size: 16),
                              label: const Text(
                                'Ver Detalle',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
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
                              onPressed: () => _confirmDelete(context, item),
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showNewConsultationMenu() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewConsultationScreen()),
    );
    // Refrescar al volver en caso de que se haya hecho una consulta
    _loadConsultations();
  }

  void _showFabOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentCyan.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: accentCyan),
                ),
                title: const Text('Nueva Consulta', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                subtitle: const Text('Hazle una pregunta al oráculo guiado por IA', style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context); // Cierra el bottom sheet
                  _showNewConsultationMenu(); // Abre la pantalla de consultas
                },
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentPurple.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite, color: accentPurple),
                ),
                title: const Text('Compatibilidad Astral', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                subtitle: const Text('Compara ambas cartas astrales', style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context); // Cierra el bottom sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CompatibilityScreen()),
                  ); // Abre la pantalla de compatibilidad
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}

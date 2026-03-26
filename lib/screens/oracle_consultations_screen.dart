import 'package:flutter/material.dart';
import '../services/oracle_service.dart';
import 'new_consultation_screen.dart';

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
              onPressed: _showNewConsultationMenu,
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
                  child: Row(
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
                        ),
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
}

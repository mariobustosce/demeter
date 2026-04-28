import 'dart:convert';
import 'package:flutter/material.dart';

const backgroundColor = Color(0xFF0A0A0F);
const accentCyan = Color(0xFF4FD0E7);
const accentPurple = Color(0xFF8B5CF6);
const cardBackground = Color(0xEF0F172A);
const textColor = Color(0xFFF7FAFC);
const secondaryTextColor = Color(0xFF94A3B8);

class ConsultationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> consultation;

  const ConsultationDetailScreen({super.key, required this.consultation});

  @override
  Widget build(BuildContext context) {
    final pregunta = consultation['pregunta'] ?? 'Sin pregunta';
    final respuesta = consultation['respuesta'] ?? consultation['response'] ?? 'Sin respuesta';
    final createdAt = consultation['created_at'] ?? '';
    final nivelContexto = consultation['nivel_contexto'] ?? 'basico';
    final modelo = consultation['modelo_ia'] ?? 'gemini-2.5-flash';
    
    // Contexto astronómico
    final contexto = consultation['contexto_astronomico'] is String 
        ? jsonDecode(consultation['contexto_astronomico']) 
        : consultation['contexto_astronomico'] ?? {};
    
    // Carta astral utilizada
    final cartaAstral = consultation['carta_astral'];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: accentCyan),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cardBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentCyan.withOpacity(0.3)),
              ),
              child: Text(
                modelo,
                style: const TextStyle(
                  color: accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatDateTime(createdAt),
              style: const TextStyle(
                color: secondaryTextColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pregunta del usuario
              _buildQuestionCard(pregunta),
              const SizedBox(height: 20),
              
              // Respuesta del oráculo
              _buildResponseCard(respuesta, nivelContexto),
              const SizedBox(height: 20),
              
              // Contexto celestial
              if (contexto.isNotEmpty) _buildCelestialContext(contexto),
              if (contexto.isNotEmpty) const SizedBox(height: 20),
              
              // Carta astral utilizada
              if (cartaAstral != null) _buildAstralChartInfo(cartaAstral),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(String pregunta) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(color: accentCyan.withOpacity(0.5)),
            ),
            child: const Icon(Icons.person, color: accentCyan, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TÚ PREGUNTASTE',
                  style: TextStyle(
                    color: accentCyan,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '"$pregunta"',
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseCard(String respuesta, String nivel) {
    Color nivelColor = accentCyan;
    if (nivel == 'premium') nivelColor = Colors.amber;
    if (nivel == 'intermedio') nivelColor = accentPurple;

    return Container(
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentCyan, accentPurple],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🔮', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 12),
                const Text(
                  'GUÍA CELESTIAL',
                  style: TextStyle(
                    color: accentCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: nivelColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    nivel.toUpperCase(),
                    style: TextStyle(
                      color: nivelColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              respuesta,
              style: const TextStyle(
                color: textColor,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCelestialContext(Map<String, dynamic> contexto) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.public, color: accentCyan, size: 20),
              SizedBox(width: 12),
              Text(
                'CONTEXTO CELESTIAL',
                style: TextStyle(
                  color: accentCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Momento
          if (contexto['momento'] != null)
            _buildContextRow('📅 Momento', contexto['momento'].toString()),
          
          // Ubicación
          if (contexto['hemisferio'] != null || contexto['estacion'] != null)
            _buildContextRow(
              '🌍 Ubicación',
              '${contexto['hemisferio'] ?? ''} · ${contexto['estacion'] ?? ''}'.trim(),
            ),
          
          // Sol
          if (contexto['sol'] != null)
            _buildSunMoonCard('☀️ Sol', contexto['sol'], Colors.amber),
          
          // Luna
          if (contexto['luna'] != null)
            _buildSunMoonCard('🌙 Luna', contexto['luna'], Colors.blue),
          
          // Casa dominante
          if (contexto['casa_dominante'] != null || contexto['zodiaco_dominante'] != null)
            _buildDominantInfo(contexto),
          
          // Planetas visibles
          if (contexto['planetas_visibles'] != null)
            _buildVisiblePlanets(contexto['planetas_visibles']),
          
          // JSON completo (expandible)
          const SizedBox(height: 16),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            iconColor: accentCyan,
            collapsedIconColor: secondaryTextColor,
            title: const Text(
              'Ver datos completos (JSON)',
              style: TextStyle(color: secondaryTextColor, fontSize: 12),
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: backgroundColor.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    const JsonEncoder.withIndent('  ').convert(contexto),
                    style: const TextStyle(
                      color: accentCyan,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContextRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: secondaryTextColor, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSunMoonCard(String title, dynamic data, Color color) {
    if (data is! Map<String, dynamic>) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              if (data['visible'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    data['visible'] == true ? 'Visible' : 'Oculto',
                    style: TextStyle(color: color, fontSize: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (data['constelacion'] != null)
            Text(
              'Constelación: ${data['constelacion']}',
              style: const TextStyle(color: secondaryTextColor, fontSize: 11),
            ),
          if (data['energia'] != null)
            Text(
              'Energía: ${data['energia']}',
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 11),
            ),
          if (data['fase'] != null)
            Text(
              'Fase: ${data['fase']}',
              style: const TextStyle(color: secondaryTextColor, fontSize: 11),
            ),
          if (data['iluminacion'] != null)
            Text(
              'Iluminación: ${data['iluminacion']}%',
              style: const TextStyle(color: textColor, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _buildDominantInfo(Map<String, dynamic> contexto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (contexto['casa_dominante'] != null)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentPurple.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Casa Dominante',
                      style: TextStyle(color: accentPurple, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contexto['casa_dominante'].toString(),
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (contexto['casa_dominante'] != null && contexto['zodiaco_dominante'] != null)
            const SizedBox(width: 12),
          if (contexto['zodiaco_dominante'] != null)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.indigo.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Zodiaco Dom.',
                      style: TextStyle(color: Colors.indigo, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contexto['zodiaco_dominante'].toString(),
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVisiblePlanets(dynamic planetas) {
    if (planetas is! List) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          '🪐 Planetas visibles:',
          style: TextStyle(color: secondaryTextColor, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: planetas.map((planeta) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: backgroundColor.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentCyan.withOpacity(0.2)),
              ),
              child: Text(
                planeta.toString(),
                style: const TextStyle(color: accentCyan, fontSize: 11),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAstralChartInfo(Map<String, dynamic> carta) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star, color: Colors.pink, size: 20),
              SizedBox(width: 12),
              Text(
                'CARTA ASTRAL UTILIZADA',
                style: TextStyle(
                  color: Colors.pink,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            carta['titulo'] ?? carta['title'] ?? 'Carta Astral',
            style: const TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildChartPoint('☀️ Sol', carta['sun_degree']?.toString() ?? '-', Colors.amber),
              ),
              Expanded(
                child: _buildChartPoint('🌙 Luna', carta['moon_degree']?.toString() ?? '-', Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildChartPoint('⬆️ ASC', carta['asc_degree']?.toString() ?? '-', accentCyan),
              ),
              Expanded(
                child: _buildChartPoint('📈 MC', carta['mc_degree']?.toString() ?? '-', accentPurple),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartPoint(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.7), fontSize: 10),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final parts = dateStr.split('T');
      if (parts.length < 2) return dateStr;
      
      final dateParts = parts[0].split('-');
      final timeParts = parts[1].split(':');
      
      if (dateParts.length == 3 && timeParts.length >= 2) {
        return '${dateParts[2]}/${dateParts[1]}/${dateParts[0]}, ${timeParts[0]}:${timeParts[1]}';
      }
    } catch (_) {}
    return dateStr;
  }
}

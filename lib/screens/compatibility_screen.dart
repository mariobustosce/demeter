import 'package:flutter/material.dart';
import '../services/astral_chart_service.dart';
import '../services/oracle_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

const backgroundColor = Color(0xFF0A0A0F);
const accentCyan = Color(0xFF4FD0E7);
const accentPurple = Color(0xFF8B5CF6);
const cardBackground = Color(0xEF0F172A);
const textColor = Color(0xFFF7FAFC);
const secondaryTextColor = Color(0xFF94A3B8);

class CompatibilityScreen extends StatefulWidget {
  const CompatibilityScreen({super.key});

  @override
  State<CompatibilityScreen> createState() => _CompatibilityScreenState();
}

class _CompatibilityScreenState extends State<CompatibilityScreen> {
  final AstralChartService _chartService = AstralChartService();
  final OracleService _oracleService = OracleService();

  List<dynamic> _charts = [];
  String? _selectedPersonA;
  String? _selectedPersonB;
  bool _isLoadingCharts = true;

  String _selectedLevel = 'Básico'; // Básico (5), Astral (10), Divino (20)
  bool _isProcessing = false;
  String? _resultMarkdown;

  @override
  void initState() {
    super.initState();
    _loadCharts();
  }

  Future<void> _loadCharts() async {
    setState(() => _isLoadingCharts = true);
    try {
      final charts = await _chartService.getUserCharts();
      setState(() {
        _charts = charts;
        _isLoadingCharts = false;
        if (_charts.length >= 2) {
          _selectedPersonA = _charts[0]['id'].toString();
          _selectedPersonB = _charts[1]['id'].toString();
        } else if (_charts.isNotEmpty) {
           _selectedPersonA = _charts[0]['id'].toString();
        }
      });
    } catch (e) {
      setState(() => _isLoadingCharts = false);
    }
  }

  void _calculateCompatibility() async {
    if (_selectedPersonA == null || _selectedPersonB == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona dos personas para comparar')),
      );
      return;
    }

    if (_selectedPersonA == _selectedPersonB) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona dos personas diferentes')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _resultMarkdown = null;
    });

    String level = 'basico';
    if (_selectedLevel == 'Astral') level = 'intermedio';
    if (_selectedLevel == 'Divino') level = 'premium';

    final result = await _oracleService.consultarCompatibilidad(
      cartaAId: _selectedPersonA!,
      cartaBId: _selectedPersonB!,
      nivelContexto: level,
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
        if (result['success']) {
          _resultMarkdown = result['texto'];
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['error'] ?? 'Error al calcular compatibilidad')),
          );
        }
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
        title: const Text(
          'Compatibilidad Energética',
          style: TextStyle(color: accentCyan, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoadingCharts 
        ? const Center(child: CircularProgressIndicator(color: accentCyan))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 25),
                _buildLevelSelector(),
                const SizedBox(height: 25),
                _buildPersonSelectors(),
                const SizedBox(height: 30),
                _buildSubmitButton(),
                if (_resultMarkdown != null) ...[
                  const SizedBox(height: 30),
                  _buildResultCard(),
                ],
              ],
            ),
          ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Row(
          children: [
             const Text('💖', style: TextStyle(fontSize: 24)),
             const SizedBox(width: 8),
             Text(
              'Sincronía Astral',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Descubre la resonancia cósmica entre dos almas usando sus cartas natales.',
          style: TextStyle(color: secondaryTextColor, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildLevelSelector() {
    final levels = [
      {'label': 'Básico', 'icon': '💝', 'cost': '5'},
      {'label': 'Astral', 'icon': '✨', 'cost': '10'},
      {'label': 'Divino', 'icon': '🔥', 'cost': '20'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: levels.map((level) {
          final isSelected = _selectedLevel == level['label'];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedLevel = level['label']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? accentPurple.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '${level['icon']} ${level['label']}',
                      style: TextStyle(
                        color: isSelected ? accentPurple : textColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${level['cost']} Polvo',
                      style: TextStyle(
                        color: isSelected ? accentPurple : secondaryTextColor,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPersonSelectors() {
    return Column(
      children: [
        _buildDropdown(
          label: 'Selecciona Persona A...',
          value: _selectedPersonA,
          onChanged: (val) => setState(() => _selectedPersonA = val),
        ),
        const SizedBox(height: 15),
        _buildDropdown(
          label: 'Selecciona Persona B...',
          value: _selectedPersonB,
          onChanged: (val) => setState(() => _selectedPersonB = val),
        ),
      ],
    );
  }

  Widget _buildDropdown({required String label, String? value, required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(label, style: const TextStyle(color: secondaryTextColor)),
          dropdownColor: const Color(0xFF1E293B),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: accentCyan),
          items: _charts.map<DropdownMenuItem<String>>((chart) {
            final String name = chart['titulo'] ?? chart['title'] ?? chart['nombre'] ?? 'Sin nombre';
            return DropdownMenuItem<String>(
              value: chart['id'].toString(),
              child: Text(
                '✨ $name',
                style: const TextStyle(color: textColor),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _calculateCompatibility,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B1E40), // Morado oscuro de la imagen
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isProcessing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'CONECTAR ALMAS',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentPurple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: accentCyan, size: 20),
              const SizedBox(width: 10),
              Text(
                'Resultado de la Consulta',
                style: TextStyle(
                  color: accentPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Divider(height: 30, color: Colors.white12),
          MarkdownBody(
            data: _resultMarkdown!,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(color: textColor, height: 1.5),
              h1: const TextStyle(color: accentCyan, fontWeight: FontWeight.bold),
              h2: const TextStyle(color: accentPurple, fontWeight: FontWeight.bold),
              strong: const TextStyle(color: accentCyan),
            ),
          ),
        ],
      ),
    );
  }
}

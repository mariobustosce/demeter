import 'package:flutter/material.dart';
import '../services/astral_chart_service.dart';
import '../services/oracle_service.dart';
import '../services/sky_service.dart';

const backgroundColor = Color(0xFF0A0A0F);
const accentCyan = Color(0xFF4FD0E7);
const accentPurple = Color(0xFF8B5CF6);
const cardBackground = Color(0xEF0F172A);
const textColor = Color(0xFFF7FAFC);
const secondaryTextColor = Color(0xFF94A3B8);

class NewConsultationScreen extends StatefulWidget {
  const NewConsultationScreen({super.key});

  @override
  State<NewConsultationScreen> createState() => _NewConsultationScreenState();
}

class _NewConsultationScreenState extends State<NewConsultationScreen> {
  final AstralChartService _chartService = AstralChartService();
  final OracleService _oracleService = OracleService();
  final SkyService _skyService = SkyService();
  
  List<dynamic> _charts = [];
  String? _selectedChartId;
  bool _isLoadingCharts = false;

  String _selectedType = 'Básico'; // Básico, Astral, Divino
  bool _useAstralChart = false;
  final TextEditingController _queryController = TextEditingController();
  bool _isConsulting = false;
  String? _response;

  @override
  void initState() {
    super.initState();
    _loadCharts();
  }

  Future<void> _loadCharts() async {
    setState(() {
      _isLoadingCharts = true;
    });
    
    final charts = await _chartService.getUserCharts();
    
    if (mounted) {
      setState(() {
        _charts = charts;
        if (_charts.isNotEmpty) {
          _selectedChartId = _charts.first['id']?.toString();
        }
        _isLoadingCharts = false;
      });
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _submitConsultation() async {
    if (_queryController.text.trim().isEmpty) return;
    
    if (_useAstralChart && _selectedChartId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona una carta astral')),
      );
      return;
    }

    setState(() {
      _isConsulting = true;
      _response = null;
    });

    // Mapeo del nivel de contexto
    String nivelContexto = 'basico';
    if (_selectedType == 'Astral') nivelContexto = 'intermedio';
    if (_selectedType == 'Divino') nivelContexto = 'premium';

    // Obtener contexto astronómico completo
    Map<String, dynamic>? contextoCompleto;
    try {
      contextoCompleto = await _skyService.getAstralProfile();
    } catch (e) {
      print("No se pudo obtener contexto completo: $e");
    }

    final result = await _oracleService.consultarAlOraculo(
      pregunta: _queryController.text.trim(),
      nivelContexto: nivelContexto,
      usaCartaAstral: _useAstralChart,
      cartaAstralId: _selectedChartId,
      contextoCompleto: contextoCompleto,
    );

    if (!mounted) return;

    if (result['success']) {
      setState(() {
        _isConsulting = false;
        _response = result['response'];
        // TODO: Actualizar balance global si es necesario result['nuevoBalance']
      });
    } else {
      setState(() {
        _isConsulting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Error desconocido'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Devuelve los tokens (Polvo Estelar y TOKENS) basado en la selección
  Map<String, String> _getCostDetails() {
    int basePolvo = 5;
    int baseTokens = 150;

    if (_selectedType == 'Astral') {
      basePolvo = 10;
      baseTokens = 300;
    } else if (_selectedType == 'Divino') {
      basePolvo = 20;
      baseTokens = 600;
    }

    if (_useAstralChart) {
      basePolvo += 50;
      baseTokens += 1500; // Asumiendo que 1 Polvo = 30 Tokens aprox
    }

    return {
      'polvo': '$basePolvo',
      'tokens': '$baseTokens',
    };
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
            Text('✨', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'ORÁCULO',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Panel de Configuración de la Consulta
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF15151D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selector de Tipo
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        _buildTypeOption('Básico', '💫'),
                        _buildTypeOption('Astral', '✨'),
                        _buildTypeOption('Divino', '🌟'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Costos
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            '${_getCostDetails()['polvo']} Polvo Estelar',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '- ${_getCostDetails()['tokens']} TOKENS',
                        style: TextStyle(
                          color: secondaryTextColor.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  
                  // Checkbox Carta Astral
                  Theme(
                    data: ThemeData(
                      unselectedWidgetColor: secondaryTextColor,
                    ),
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: accentCyan,
                      checkColor: Colors.black,
                      title: const Text(
                        'USAR CARTA ASTRAL (+50 ✨)',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      value: _useAstralChart,
                      onChanged: (val) {
                        setState(() {
                          _useAstralChart = val ?? false;
                        });
                      },
                    ),
                  ),

                  // Desplegable de Cartas Astrales si está seleccionado
                  if (_useAstralChart) ...[
                    const SizedBox(height: 8),
                    _isLoadingCharts
                        ? const Padding(
                            padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: accentCyan, strokeWidth: 2),
                            ),
                          )
                        : _charts.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                                child: Text(
                                  'No tienes cartas astrales creadas. Crea una primero.',
                                  style: TextStyle(color: Colors.red[300], fontSize: 13),
                                ),
                              )
                            : Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: accentCyan.withOpacity(0.3)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedChartId,
                                    isExpanded: true,
                                    hint: const Text(
                                      'Selecciona una carta astral',
                                      style: TextStyle(color: secondaryTextColor, fontSize: 14),
                                    ),
                                    dropdownColor: const Color(0xFF1A1A24),
                                    icon: const Icon(Icons.keyboard_arrow_down, color: accentCyan),
                                    items: _charts.map<DropdownMenuItem<String>>((chart) {
                                      final id = chart['id']?.toString() ?? '';
                                      final title = chart['titulo'] ?? chart['title'] ?? 'Carta Astral';
                                      final sign = chart['sun_sign'] ?? '';
                                      
                                      return DropdownMenuItem<String>(
                                        value: id,
                                        child: Text(
                                          '$title ${sign.isNotEmpty ? '($sign)' : ''}',
                                          style: const TextStyle(color: textColor, fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        _selectedChartId = newValue;
                                      });
                                    },
                                  ),
                                ),
                              ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Área de Pregunta / Respuesta
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF15151D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✨ NUEVA CONSULTA',
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Si ya hay respuesta, mostrarla en lugar del campo de texto
                  if (_response != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: accentPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentPurple.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome, color: accentPurple, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Respuesta del Oráculo',
                                style: TextStyle(
                                  color: accentPurple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _response!,
                            style: const TextStyle(
                              color: textColor,
                              fontSize: 15,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    TextField(
                      controller: _queryController,
                      maxLines: 6,
                      maxLength: 300,
                      style: const TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Escribe tu consulta al universo...',
                        hintStyle: TextStyle(color: secondaryTextColor.withOpacity(0.5)),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        counterStyle: const TextStyle(color: secondaryTextColor),
                      ),
                      onChanged: (text) => setState(() {}), // Actualizar estado para botón
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Botón de Acción
                  if (_response == null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _queryController.text.trim().isEmpty || _isConsulting
                            ? null
                            : _submitConsultation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentPurple,
                          disabledBackgroundColor: accentPurple.withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isConsulting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'REVELAR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                      ),
                    )
                  else
                    Align(
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _response = null;
                            _queryController.clear();
                          });
                        },
                        icon: const Icon(Icons.refresh, color: accentCyan),
                        label: const Text(
                          'HACER OTRA CONSULTA',
                          style: TextStyle(color: accentCyan),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(String title, String emoji) {
    bool isSelected = _selectedType == title;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = title;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? accentPurple.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? accentPurple : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : secondaryTextColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

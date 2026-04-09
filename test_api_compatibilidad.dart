
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://windowsdemeter.com/api/oraculo/compatibilidad');
  print('--- PROBANDO ENDPOINT DE COMPATIBILIDAD (CORREGIDO) ---');
  print('URL: $url');
  
  try {
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'carta1_id': 1, // IDs de prueba comunes
        'carta2_id': 2,
      }),
    ).timeout(Duration(seconds: 10));

    print('STATUS CODE: ${response.statusCode}');
    print('RESPONSE BODY: ${response.body}');
  } catch (e) {
    print('ERROR EN LA PETICION: $e');
  }
}

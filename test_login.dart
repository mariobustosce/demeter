import 'dart:convert';
import 'package:http/http.dart' as http;
void main() async {
  print('Iniciando test...');
  var res = await http.post(
    Uri.parse('https://windowsdemeter.com/api/login'),
    headers: { 'Accept': 'application/json', 'Content-Type': 'application/json' },
    body: jsonEncode({'email': 'test@example.com', 'password': 'password123', 'device_name': 'test'})
  );
  print('Status: ' + res.statusCode.toString());
  print('Body: ' + res.body);
}

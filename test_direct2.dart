import 'dart:io';
import 'dart:convert';
void main() async {
  final url = Uri.parse('https://windowsdemeter.com/api/astronomy/map-svg-mobile?lat=-30.7128&lon=-73.606&date=2026-04-05&time=20:30');
  final request = await HttpClient().getUrl(url);
  final response = await request.close();
  final stringData = await response.transform(utf8.decoder).join();
  print('HTTP \');
  print(stringData.substring(0, stringData.length > 300 ? 300 : stringData.length));
}

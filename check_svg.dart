import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final res = await http.get(Uri.parse('http://demeter.test/api/astronomy/map-svg-mobile?lat=-34.6&lon=-58.4&date=2023-01-01&time=12:00'));
  final svg = res.body;
  print(svg.substring(0, 500 > svg.length ? svg.length : 500));
}

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final res = await http.get(Uri.parse('http://demeter.test/api/astronomy/map-svg-mobile?lat=-34.6&lon=-58.4&date=2023-01-01&time=12:00'));
  print(res.statusCode);
  if(res.body.length > 200) print(res.body.substring(0, 200));
}

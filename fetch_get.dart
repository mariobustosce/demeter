import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse("https://windowsdemeter.com/api/astronomy/map-svg");
  final res = await http.get(
    url,
    headers: {
      'Accept': 'application/json',
    },
    body: {
      'lat': '-34.60',
        'lng': '-58.38',
        'date': '2026-03-26',
        'time': '12:00'
    }
  );
  print("POST Status: ${res.statusCode}");
  if (res.body.length > 200) {
    print("Body: ${res.body.substring(0, 200)}...");
  } else {
    print("Body: ${res.body}");
  }
}

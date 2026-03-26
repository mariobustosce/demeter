import 'dart:io';

void main() {
  final file = File('lib/services/sky_service.dart');
  final content = file.readAsStringSync();
  print(content.contains('json.decode') ? 'Contains json' : 'No json');
}

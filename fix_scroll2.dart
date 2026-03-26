import 'dart:io';

void main() {
  var file = File('lib/screens/home_screen_v2.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('SingleChildScrollView(', 'SingleChildScrollView( physics: const NeverScrollableScrollPhysics(), ');
  file.writeAsStringSync(content);
}

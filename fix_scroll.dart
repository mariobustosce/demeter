import 'dart:io';

void main() {
  var file = File('lib/screens/home_screen_v2.dart');
  var content = file.readAsStringSync();

  content = content.replaceAll('Expanded(child: SingleChildScrollView(', 'SingleChildScrollView(');
  // remove the SingleChildScrollView inside the ListView since we already have ListView as the scroll context
  // Actually, replacing SingleChildScrollView with Column if it was there would be better, but wait, SingleChildScrollView inside ListView shrinkWraps anyway? No, it could expand infinitely.
  // It's safer to just replace 'Expanded(child: SingleChildScrollView(' with 'SingleChildScrollView( physics: NeverScrollableScrollPhysics(), '. Wait, better yet, replace it with nothing if I can.
  // Let's just do a string replace:
  content = content.replaceAll('Expanded(child: SingleChildScrollView(', 'SingleChildScrollView( physics: const NeverScrollableScrollPhysics(), ');

  file.writeAsStringSync(content);
}

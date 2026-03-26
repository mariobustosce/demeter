import 'dart:io';

void main() {
  final file = File('lib/screens/home_screen_v2.dart');
  final lines = file.readAsLinesSync();
  
  final startBuild = lines.indexWhere((l) => l.contains('Widget build(BuildContext context) {'));
  final endBuildTitle = lines.indexWhere((l) => l.contains('Widget _buildSectionTitle(String title) {'));
  
  if (startBuild != -1 && endBuildTitle != -1) {
    print(startBuild);
    print(endBuildTitle - 1);
  } else {
    print('Not found');
  }
}

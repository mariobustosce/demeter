import 'dart:io';
void main() {
  var fileOriginal = File('lib/screens/home_screen.dart');
  var content = fileOriginal.readAsStringSync();
  
  var buildStart = content.indexOf('Widget build(BuildContext context) {');
  var beforeBuild = content.substring(0, buildStart);
  
  beforeBuild = beforeBuild.replaceAll('class HomeScreen ', 'class HomeScreenV2 ');
  beforeBuild = beforeBuild.replaceAll('class _HomeScreenState ', 'class _HomeScreenV2State ');
  beforeBuild = beforeBuild.replaceAll('State<HomeScreen>', 'State<HomeScreenV2>');
  beforeBuild = beforeBuild.replaceAll('const HomeScreen({super.key});', 'const HomeScreenV2({super.key});');
  beforeBuild = beforeBuild.replaceAll('createState() => _HomeScreenState();', 'createState() => _HomeScreenV2State();');

  beforeBuild = beforeBuild.replaceAll('late Future<Map<String, dynamic>?> _skyMapFuture;', 'late Future<String?> _svgMapFuture;');
  beforeBuild = beforeBuild.replaceAll('_skyMapFuture = Future.value(null);', '_svgMapFuture = Future.value(null);');
  beforeBuild = beforeBuild.replaceAll('_skyMapFuture = skyFuture;', '_svgMapFuture = _skyService.getMapSvgMobile(lat: lat, lng: lon, date: dt);');
  
  var scrollStart = content.indexOf('FutureBuilder<Map<String, dynamic>>(');
  var scrollEnd = content.indexOf('// Cierra Expanded de la zona scrollable');
  
  var extractedContent = content.substring(scrollStart, scrollEnd);
  
  // We need to strip out the end properly. scrollEnd is right after ), corresponding to Expanded.
  // The actual extractedContent ends with                       ),
  // We will just put it in a ListView.
  // Let's strip the last \n                    ],\n                  ),\n                ),  which is 4 closing tags.
  // Actually, we can just replace the entire build method.

}

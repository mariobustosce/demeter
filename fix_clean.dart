import 'dart:io';
void main() {
  var fileOriginal = File('lib/screens/home_screen.dart');
  var content = fileOriginal.readAsStringSync();
  
  var buildStart = content.indexOf('Widget build(BuildContext context) {');
  var helpersStart = content.indexOf('Widget _buildSectionTitle');

  var beforeBuild = content.substring(0, buildStart);
  var afterBuild = content.substring(helpersStart);
  
  beforeBuild = beforeBuild.replaceAll('class HomeScreen ', 'class HomeScreenV2 ');
  beforeBuild = beforeBuild.replaceAll('class _HomeScreenState ', 'class _HomeScreenV2State ');
  beforeBuild = beforeBuild.replaceAll('State<HomeScreen>', 'State<HomeScreenV2>');
  beforeBuild = beforeBuild.replaceAll('const HomeScreen({super.key});', 'const HomeScreenV2({super.key});');
  beforeBuild = beforeBuild.replaceAll('createState() => _HomeScreenState();', 'createState() => _HomeScreenV2State();');

  beforeBuild = beforeBuild.replaceAll('late Future<Map<String, dynamic>?> _skyMapFuture;', 'late Future<String?> _svgMapFuture;');
  beforeBuild = beforeBuild.replaceAll('_skyMapFuture = Future.value(null);', '_svgMapFuture = Future.value(null);');
  beforeBuild = beforeBuild.replaceAll('_skyMapFuture = skyFuture;', '_svgMapFuture = _skyService.getMapSvgMobile(lat: lat, lng: lon, date: dt);');
  
  var futureStartStr = 'FutureBuilder<Map<String, dynamic>>(';
  var futureStart = content.indexOf(futureStartStr);
  
  // The futurebuilder ends at line 1856 which is exactly '}, \n ),'
  // Actually, we can just find '                  ), // Cierra Expanded' and look back.
  var expandedEnd = content.indexOf('// Cierra Expanded de la zona scrollable');
  var extracted = content.substring(futureStart, expandedEnd);
  // extracted contains FutureBuilder ... ] ) ) ] ) )
  // We want to discard the closing tags.
  // The closing sequence is:
  /*
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ), 
  */
  // So we can split by '                              },\n                            ),'
  var cutoff = extracted.indexOf('                              },\n                            ),');
  cutoff += '                              },\n                            ),'.length;
  var futureBuilderCode = extracted.substring(0, cutoff);

  var newBuild = '''  void _mostrarMenuDetalles() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: backgroundColor,
                ),
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.only(top: 10, bottom: 40),
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    ''' + futureBuilderCode + '''
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: FutureBuilder<String?>(
              future: _svgMapFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: accentCyan));
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                  return const Center(
                    child: Text("No se pudo cargar el mapa celestial.", style: TextStyle(color: Colors.white54)),
                  );
                }

                return SvgPicture.string(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  allowDrawingOutsideViewBox: true,
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarMenuDetalles,
        backgroundColor: accentPurple.withOpacity(0.9),
        icon: const Icon(Icons.explore, color: Colors.white),
        label: const Text("Planetas", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

''';

  File('lib/screens/home_screen_v2.dart').writeAsStringSync(beforeBuild + newBuild + afterBuild);
  print('COMPLETED SCRIPING');
}

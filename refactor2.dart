import 'dart:io';

void main() {
  var fileOriginal = File('lib/screens/home_screen.dart');
  var content = fileOriginal.readAsStringSync();

  content = content.replaceAll('class HomeScreen ', 'class HomeScreenV2 ');
  content = content.replaceAll('class _HomeScreenState ', 'class _HomeScreenV2State ');
  content = content.replaceAll('State<HomeScreen>', 'State<HomeScreenV2>');
  
  content = content.replaceAll('late Future<Map<String, dynamic>?> _skyMapFuture;', 'late Future<String?> _svgMapFuture;');
  content = content.replaceAll('_skyMapFuture = Future.value(null);', '_svgMapFuture = Future.value(null);');
  content = content.replaceAll('_skyMapFuture = skyFuture;', '_svgMapFuture = _skyService.getMapSvgMobile(lat: lat, lng: lon, date: dt);');

  var buildStart = content.indexOf('Widget build(BuildContext context) {');
  var helpersStart = content.indexOf('Widget _buildSectionTitle');

  if (buildStart != -1 && helpersStart != -1) {
    var beforeBuild = content.substring(0, buildStart);
    var originalBuild = content.substring(buildStart, helpersStart);
    var afterBuild = content.substring(helpersStart);

    var scrollStart = originalBuild.indexOf('SingleChildScrollView(');
    var scrollEnd = originalBuild.indexOf('// Cierra Expanded de la zona scrollable');
    
    var infoContent = 'Text("Extracted content not found");';
    if (scrollStart != -1 && scrollEnd != -1) {
      infoContent = originalBuild.substring(scrollStart, scrollEnd);
    }

    // Using string concatenation to avoid \$ issue in powershell
    var newBuild = '''
  void _mostrarMenuDetalles() {
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
                    ''' + infoContent + '''
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
          // Mapa de fondo
          Positioned.fill(
            child: FutureBuilder<String?>(
              future: _svgMapFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: accentCyan),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                  return const Center(
                    child: Text(
                      "No se pudo cargar el mapa celestial.",
                      style: TextStyle(color: Colors.white54),
                    ),
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
        label: const Text("Planetas y Astrología", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

''';

    File('lib/screens/home_screen_v2.dart').writeAsStringSync(beforeBuild + newBuild + afterBuild);
    print("DONE");
  } else {
    print("FAILED TO FIND BUILD METHOD");
  }
}

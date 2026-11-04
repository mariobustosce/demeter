import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'api_client.dart';

/// Guarda un archivo descargado y abre la hoja de compartir del sistema,
/// desde donde se guarda en Archivos, Drive, etc.
typedef CompartirArchivo = Future<void> Function(Descarga descarga, String nombre);

/// Lo escribe en la carpeta temporal de la app, solo para entregarlo: la app
/// no lo vuelve a leer (cada descarga es un cobro).
Future<void> compartirArchivo(Descarga descarga, String nombre) async {
  final dir = await getTemporaryDirectory();
  final archivo = File('${dir.path}${Platform.pathSeparator}$nombre');
  await archivo.writeAsBytes(descarga.bytes, flush: true);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(archivo.path, mimeType: descarga.tipo?.split(';').first.trim())],
    subject: nombre,
  ));
}

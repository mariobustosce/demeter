import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

/// Miniaturas SVG de los paisajes, guardadas en memoria y en disco.
///
/// Son públicas (sin token) y comparten con el mapa el límite de 60/min por
/// IP: se piden una vez y se reusan mientras valga su `max-age` (1 h). Después
/// se revalidan con `If-None-Match` y, si el servidor responde 304, sigue la
/// misma. Solo se piden al sitio de la app.
class LandscapeThumbnails {
  LandscapeThumbnails({
    http.Client? httpClient,
    Future<Directory?> Function()? directory,
    DateTime Function()? clock,
    String? webBase,
  })  : _http = httpClient ?? http.Client(),
        _directory = directory ?? _defaultDirectory,
        _clock = clock ?? DateTime.now,
        _origin = Uri.parse(webBase ?? kWebBase).origin;

  /// Instancia que usa la app. Los tests pueden reemplazarla.
  static LandscapeThumbnails instance = LandscapeThumbnails();

  /// El `Cache-Control: max-age` que manda el servidor.
  static const Duration fresh = Duration(hours: 1);

  final http.Client _http;
  final Future<Directory?> Function() _directory;
  final DateTime Function() _clock;
  final String _origin;

  final Map<String, _Thumb> _memory = {};
  final Map<String, Future<Uint8List?>> _pending = {};
  Future<Directory?>? _dir;

  /// El SVG, o `null` si no hay forma de tenerlo (sin red la primera vez, una
  /// clave que ya no existe o una URL de otro sitio).
  Future<Uint8List?> load(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.origin != _origin || uri.userInfo.isNotEmpty) {
      return Future.value(null);
    }
    final key = uri.toString();
    final running = _pending[key];
    if (running != null) return running;
    final future = _load(key, uri);
    _pending[key] = future;
    future.whenComplete(() => _pending.remove(key)).ignore();
    return future;
  }

  Future<Uint8List?> _load(String key, Uri uri) async {
    var cached = _memory[key] ?? await _readDisk(key);
    if (cached != null) {
      _memory[key] = cached;
      if (_clock().difference(cached.fetchedAt) < fresh) return cached.body;
    }

    try {
      final etag = cached?.etag;
      final response = await _http.get(uri, headers: {
        'Accept': 'image/svg+xml',
        'If-None-Match': ?etag,
      }).timeout(kRequestTimeout);

      if (response.statusCode == 304 && cached != null) {
        cached = _Thumb(cached.body, cached.etag, _clock());
        await _store(key, cached);
        return cached.body;
      }
      if (response.statusCode == 200 && _isSvg(response)) {
        cached = _Thumb(response.bodyBytes, response.headers['etag'], _clock());
        await _store(key, cached);
        return cached.body;
      }
      // La URL no se registra: es pública, pero no hace falta.
      debugPrint('Miniatura: el servidor respondió ${response.statusCode}.');
    } catch (e) {
      debugPrint('Miniatura no disponible (${e.runtimeType}).');
    }
    // Una vieja sirve más que nada.
    return cached?.body;
  }

  /// Una redirección al login, por ejemplo, llega como HTML con 200.
  static bool _isSvg(http.Response response) =>
      (response.headers['content-type'] ?? '').contains('svg') &&
      response.bodyBytes.isNotEmpty;

  Future<void> _store(String key, _Thumb thumb) async {
    _memory[key] = thumb;
    final file = await _file(key);
    if (file == null) return;
    try {
      await file.writeAsBytes(thumb.body, flush: true);
      await File('${file.path}.json').writeAsString(jsonEncode({
        'etag': thumb.etag,
        'fetched_at': thumb.fetchedAt.toIso8601String(),
      }));
    } catch (e) {
      debugPrint('Miniatura: no se pudo guardar (${e.runtimeType}).');
    }
  }

  Future<_Thumb?> _readDisk(String key) async {
    final file = await _file(key);
    if (file == null) return null;
    try {
      final meta = File('${file.path}.json');
      if (!await file.exists() || !await meta.exists()) return null;
      final data = jsonDecode(await meta.readAsString());
      if (data is! Map) return null;
      final fetchedAt = DateTime.tryParse('${data['fetched_at']}');
      if (fetchedAt == null) return null;
      final etag = data['etag'];
      return _Thumb(
        await file.readAsBytes(),
        etag is String ? etag : null,
        fetchedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<File?> _file(String key) async {
    final dir = await (_dir ??= _directory());
    if (dir == null) return null;
    // La URL entera como nombre, con solo letras, números y guiones.
    final name = key.replaceAll(RegExp(r'[^A-Za-z0-9-]+'), '_');
    return File('${dir.path}${Platform.pathSeparator}$name.svg');
  }

  static Future<Directory?> _defaultDirectory() async {
    try {
      final base = await getApplicationCacheDirectory();
      final dir = Directory('${base.path}${Platform.pathSeparator}paisajes');
      await dir.create(recursive: true);
      return dir;
    } catch (e) {
      // Sin disco queda la memoria.
      debugPrint('Miniaturas sin caché en disco (${e.runtimeType}).');
      return null;
    }
  }
}

class _Thumb {
  const _Thumb(this.body, this.etag, this.fetchedAt);

  final Uint8List body;
  final String? etag;
  final DateTime fetchedAt;
}

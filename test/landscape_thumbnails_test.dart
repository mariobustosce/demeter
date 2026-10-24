import 'dart:io';

import 'package:demeter/services/landscape_thumbnails.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const url = 'https://windowsdemeter.com/paisajes/castillo-wulff/miniatura';
  const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 245"/>';

  late List<http.Request> requests;
  late DateTime now;
  late http.Response Function(http.Request) respond;
  late Directory dir;

  setUp(() async {
    requests = [];
    now = DateTime(2026, 10, 23, 12);
    respond = (_) => http.Response(svg, 200, headers: {
          'content-type': 'image/svg+xml',
          'etag': '"v1"',
        });
    dir = await Directory.systemTemp.createTemp('miniaturas');
  });

  tearDown(() => dir.delete(recursive: true));

  LandscapeThumbnails thumbnails({bool disk = false}) => LandscapeThumbnails(
        httpClient: MockClient((req) async {
          requests.add(req);
          return respond(req);
        }),
        directory: () async => disk ? dir : null,
        clock: () => now,
        webBase: 'https://windowsdemeter.com',
      );

  test('la pide una vez, sin token, y la reusa mientras está fresca', () async {
    final cache = thumbnails();

    final results = await Future.wait([cache.load(url), cache.load(url)]);
    now = now.add(const Duration(minutes: 59));
    final again = await cache.load(url);

    expect(String.fromCharCodes(results[0]!), svg);
    expect(results[1], results[0]);
    expect(again, results[0]);
    expect(requests, hasLength(1));
    expect(requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('pasada la hora revalida con el ETag y un 304 conserva la misma', () async {
    final cache = thumbnails();
    final first = await cache.load(url);

    now = now.add(const Duration(hours: 1, minutes: 1));
    respond = (_) => http.Response('', 304);
    final again = await cache.load(url);

    expect(requests, hasLength(2));
    expect(requests.last.headers['If-None-Match'], '"v1"');
    expect(again, first);

    // El 304 la deja fresca otra hora.
    now = now.add(const Duration(minutes: 30));
    await cache.load(url);
    expect(requests, hasLength(2));
  });

  test('queda en disco para la próxima vez que se abre la app', () async {
    await thumbnails(disk: true).load(url);

    final fresh = thumbnails(disk: true);
    final loaded = await fresh.load(url);

    expect(String.fromCharCodes(loaded!), svg);
    expect(requests, hasLength(1));
  });

  test('sin red sirve la vieja; sin ninguna, null', () async {
    final cache = thumbnails();
    final first = await cache.load(url);

    now = now.add(const Duration(hours: 2));
    respond = (_) => throw http.ClientException('sin red');
    expect(await cache.load(url), first);

    expect(await cache.load('$url?momento=noche'), isNull);
  });

  test('una respuesta que no es SVG (la redirección al login) no se guarda', () async {
    respond = (_) => http.Response('<!DOCTYPE html>', 200, headers: {
          'content-type': 'text/html; charset=utf-8',
        });

    expect(await thumbnails().load(url), isNull);
  });

  test('no pide URLs de otros sitios', () async {
    final cache = thumbnails();

    expect(await cache.load('https://otro.example/paisajes/x/miniatura'), isNull);
    expect(await cache.load('http://windowsdemeter.com/paisajes/x/miniatura'), isNull);
    expect(await cache.load('https://user@windowsdemeter.com/paisajes/x/miniatura'), isNull);
    expect(requests, isEmpty);
  });
}

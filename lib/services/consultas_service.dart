import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/consultas.dart';
import '../theme/consultas_theme.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'coin_balance.dart';
import 'location_service.dart';

/// Una consulta que no llegó a responderse. [sinSaldo] es el 403
/// `insufficient_coins`: el ApiClient ya abrió la tienda.
class ConsultaFallida implements Exception {
  const ConsultaFallida(this.mensaje, {this.sinSaldo = false});

  final String mensaje;
  final bool sinSaldo;

  @override
  String toString() => mensaje;
}

/// La consola de Consultas contra el servidor: catálogo, cielo del momento,
/// los tres módulos, historial y notas (ver «Consultas» y «Oráculo» en
/// docs/api-app-movil.md).
class ConsultasService {
  ConsultasService({ApiClient? api, Future<void> Function()? refrescarSaldo, LocationService? ubicacion})
      : _apiOverride = api,
        _refrescarSaldo = refrescarSaldo,
        _ubicacionOverride = ubicacion;

  final ApiClient? _apiOverride;
  final Future<void> Function()? _refrescarSaldo;
  final LocationService? _ubicacionOverride;

  ApiClient get _api => _apiOverride ?? ApiClient.instance;
  LocationService get _ubicacion => _ubicacionOverride ?? LocationService.instance;

  /// El catálogo no cambia durante la sesión.
  static CatalogoConsultas? _catalogo;

  @visibleForTesting
  static void olvidarCatalogo() => _catalogo = null;

  Future<CatalogoConsultas> catalogo() async =>
      _catalogo ??= CatalogoConsultas.fromJson(jsonMap(await _api.get('/consultas/catalogo')));

  /// El cielo y el clima de ahora. Sin permiso de ubicación va sin lat/lon y
  /// el servidor usa la ubicación predeterminada. Las coordenadas ya vienen
  /// redondeadas a 2 decimales y no vuelven en la respuesta.
  Future<ContextoMomento> contexto() async {
    final lugar = await _ubicacion.current();
    return ContextoMomento.fromJson(jsonMap(await _api.get(
      '/consultas/contexto',
      query: lugar == null ? null : {'lat': lugar.latParam, 'lon': lugar.lonParam},
      timeout: kApiTimeout,
    )));
  }

  /// Demeter u Oráculo.
  Future<RespuestaConsulta> consultar({
    required ModuloConsulta modulo,
    required String pregunta,
    required String nivel,
    String? proveedor,
    Map<String, dynamic> contexto = const {},
    int? cartaId,
  }) =>
      _enviar('/oraculo/consultar', {
        'pregunta': pregunta,
        'modulo': modulo.clave,
        'nivel_contexto': nivel,
        'proveedor': ?proveedor,
        'contexto_completo': contexto,
        'usa_carta_astral': cartaId != null,
        'carta_astral_id': cartaId,
      });

  /// Perséfone.
  Future<RespuestaConsulta> compatibilidad({
    required int cartaA,
    required int cartaB,
    required String nivel,
    String? proveedor,
  }) =>
      _enviar('/oraculo/compatibilidad', {
        'carta_a_id': cartaA,
        'carta_b_id': cartaB,
        'nivel_contexto': nivel,
        'proveedor': ?proveedor,
      });

  Future<RespuestaConsulta> _enviar(String ruta, Map<String, dynamic> cuerpo) async {
    try {
      final data = jsonMap(await _api.post(ruta, body: cuerpo, timeout: kOracleTimeout));
      final saldo = data['nuevo_balance'];
      if (saldo != null) {
        updateCoinBalance(saldo);
      } else {
        unawaited(_saldo());
      }
      // Un 200 también puede ser un fracaso, con el polvo ya devuelto.
      if (data['success'] != true) {
        throw ConsultaFallida(apiMessage(data) ?? 'No se pudo completar la consulta.');
      }
      return RespuestaConsulta.fromJson(data);
    } on InsufficientCoinsException catch (e) {
      updateCoinBalance(e.balance);
      throw ConsultaFallida(e.message, sinSaldo: true);
    } on ApiException catch (e) {
      // El error no trae `nuevo_balance` aunque el polvo se devolvió.
      unawaited(_saldo());
      throw ConsultaFallida(e.message);
    }
  }

  Future<void> _saldo() async {
    try {
      await (_refrescarSaldo ?? () => AuthService().getMe())();
    } catch (_) {}
  }

  /// `GET /api/user/history?page=`: 15 por página.
  Future<PaginaHistorial> historial({int pagina = 1}) async {
    final body = jsonMap(await _api.get('/user/history', query: {'page': '$pagina'}));
    final pag = body['data'] is Map ? body['data'] as Map : const {};
    final lista = pag['data'] is List ? pag['data'] as List : const [];
    int entero(Object? v, int d) => v is num ? v.toInt() : d;
    return PaginaHistorial(
      consultas: lista.map(Consulta.fromJson).whereType<Consulta>().toList(),
      pagina: entero(pag['current_page'], pagina),
      ultima: entero(pag['last_page'], pagina),
      total: entero(pag['total'], lista.length),
    );
  }

  Future<Consulta> detalle(int id) async {
    final body = jsonMap(await _api.get('/user/history/$id'));
    return Consulta.fromJson(body['data']) ?? (throw const ApiException('Respuesta inesperada del servidor.'));
  }

  Future<void> borrar(int id) => _api.delete('/user/history/$id');

  Future<NotaConsulta> agregarNota(int id, String contenido) async {
    final body = jsonMap(await _api.post('/user/history/$id/notas', body: {'contenido': contenido}));
    return NotaConsulta.fromJson(body['nota']) ?? (throw const ApiException('Respuesta inesperada del servidor.'));
  }
}

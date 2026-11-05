import 'package:flutter/material.dart';

/// Tokens de diseño de la consola de Consultas: los mismos de la web
/// (`.cns-*` de consultas/index y `.cd-*` de consultas/show). Las pantallas y
/// los widgets de consultas no llevan colores sueltos: todo sale de aquí.
abstract final class CnsColores {
  // Fondo (`.cns-root`).
  static const fondoA = Color(0xFF05060C);
  static const fondoB = Color(0xFF0B1020);
  static const fondoC = Color(0xFF0A0F1D);
  static const haloCian = Color.fromRGBO(79, 208, 231, .10);
  static const haloVioleta = Color.fromRGBO(139, 92, 246, .12);
  static const estrella = Color(0xFFFFFFFF);

  // Texto.
  static const titulo = Color(0xFFF8FAFC);
  static const texto = Color(0xFFE2E8F0);
  static const textoFuerte = Color(0xFFF1F5F9);
  static const slate400 = Color(0xFF94A3B8);
  static const slate300 = Color(0xFFCBD5E1);
  static Color slate(double a) => slate400.withValues(alpha: a);

  // Superficies.
  static const consolaA = Color.fromRGBO(15, 23, 42, .72);
  static const consolaB = Color.fromRGBO(2, 6, 23, .78);
  static const pozo = Color.fromRGBO(2, 6, 23, .42);
  static const pozoHondo = Color.fromRGBO(2, 6, 23, .55);
  static const resumenA = Color.fromRGBO(30, 41, 59, .5);
  static const resumenB = Color.fromRGBO(2, 6, 23, .72);
  static const tarjetaA = Color.fromRGBO(15, 23, 42, .55);
  static const tarjetaB = Color.fromRGBO(2, 6, 23, .6);
  static const toast = Color.fromRGBO(15, 23, 42, .96);
  static const hoja = Color(0xFF0B1220);
  static const velo = Color.fromRGBO(2, 6, 23, .35);
  static const caja = Color.fromRGBO(2, 6, 23, .5);
  static const brillo = Color.fromRGBO(255, 255, 255, .02);
  static const brilloTenue = Color.fromRGBO(255, 255, 255, .018);
  static const sombra = Color.fromRGBO(0, 0, 0, .34);
  static const selloFondo = Color.fromRGBO(0, 0, 0, .35);
  static const transparente = Color(0x00000000);
  static const chipTexto = Color.fromRGBO(165, 243, 252, .8);
  static const enlace = Color(0xFF60A5FA);

  // Acentos comunes.
  static const cian = Color(0xFF4FD0E7);
  static const cianClaro = Color(0xFF67E8F9);
  static const violeta = Color(0xFF8B5CF6);
  static const ambar = Color(0xFFFDE68A);
  static const oro = Color(0xFFF5D76E);
  static const error = Color(0xFFF87171);

  // Cabecera: la segunda línea del título.
  static const tituloDegradado = [Color(0xFF86EFAC), Color(0xFF67E8F9), Color(0xFFA78BFA)];

  // Detalle (`.cd-*`).
  static const panel = Color.fromRGBO(9, 10, 20, .8);
  static const panelBorde = Color.fromRGBO(45, 55, 72, .55);
  static const panelLinea = Color.fromRGBO(139, 92, 246, .16);
  static const panelTopA = Color.fromRGBO(79, 208, 231, .07);
  static const panelTopB = Color.fromRGBO(139, 92, 246, .07);
  static const datoRotulo = Color(0xFF7C8EA1);
  static const detalleTexto = Color(0xFFD9D6EA);
  static const detalleTitulo = Color(0xFFF2F0FB);
  static const detalleMeta = Color(0xFF8493A6);
  static const detalleFecha = Color(0xFF9FB0C4);

  // Descargo (`x-descargo`).
  static const descargoFondo = Color.fromRGBO(30, 41, 59, .55);
  static const descargoBorde = Color(0xFFF59E0B);
  static const descargoFuerte = Color(0xFFFBBF24);
}

abstract final class CnsRadios {
  static const consola = 24.0;
  static const consolaTelefono = 18.0;
  static const tarjeta = 16.0;
  static const casilla = 14.0;
  static const boton = 15.0;
  static const resumen = 20.0;
  static const panel = 14.0;
  static const pildora = 999.0;
}

abstract final class CnsEspacios {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Por debajo de este ancho la consola se pinta «de teléfono».
  static const anchoTelefono = 640.0;

  /// Desde este ancho las franjas van en 5 columnas.
  static const anchoFranjaAncha = 700.0;
}

/// Serif para títulos y preguntas (Georgia en la web); sans para el resto.
abstract final class CnsTipos {
  static const serif = 'serif';
  static const serifRespaldo = ['Georgia', 'Noto Serif', 'Times New Roman'];

  static TextStyle serifStyle({
    double size = 16,
    Color color = CnsColores.titulo,
    FontStyle style = FontStyle.normal,
    double height = 1.3,
  }) =>
      TextStyle(
        fontFamily: serif,
        fontFamilyFallback: serifRespaldo,
        fontSize: size,
        fontStyle: style,
        fontWeight: FontWeight.w400,
        height: height,
        color: color,
      );

  /// Rótulo pequeño en mayúsculas espaciadas (`.cns-eyebrow` y parecidos).
  static TextStyle cejilla({
    double size = 10,
    double tracking = .26,
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) =>
      TextStyle(
        fontSize: size,
        letterSpacing: size * tracking,
        fontWeight: weight,
        color: color ?? CnsColores.slate(.72),
      );
}

abstract final class CnsDuraciones {
  static const panel = Duration(milliseconds: 300);
  static const nivel = Duration(milliseconds: 250);
  static const titileo = Duration(seconds: 5);
  static const giro = Duration(milliseconds: 300);
}

/// Los tres módulos de la consola. `nota_ia` solo aparece en el historial.
enum ModuloConsulta {
  demeter('demeter'),
  oraculo('oraculo'),
  persefone('persefone'),
  notaIa('nota_ia');

  const ModuloConsulta(this.clave);
  final String clave;

  static ModuloConsulta desde(Object? clave) => ModuloConsulta.values
      .firstWhere((m) => m.clave == clave, orElse: () => ModuloConsulta.oraculo);

  /// Las pestañas de la consola, en el orden de la web.
  static const consola = [demeter, oraculo, persefone];

  ModuloEstilo get estilo => switch (this) {
        demeter => ModuloEstilo.demeter,
        oraculo => ModuloEstilo.oraculo,
        persefone => ModuloEstilo.persefone,
        notaIa => ModuloEstilo.notaIa,
      };
}

/// Los colores de un módulo: pestaña, nivel elegido, botón, insignia, sello
/// y rótulos.
@immutable
class ModuloEstilo {
  const ModuloEstilo({
    required this.icono,
    required this.sello,
    required this.pestana,
    required this.nivelBorde,
    required this.nivelTinte,
    required this.boton,
    required this.botonSombra,
    required this.botonTexto,
    required this.insigniaBorde,
    required this.insigniaTexto,
    required this.rotulo,
    required this.casillaBorde,
    required this.casillaFondo,
    required this.casillaRotulo,
    required this.casillaValor,
    required this.temaPrevia,
  });

  final String icono;

  /// El color del sello en el detalle.
  final Color sello;
  final List<Color> pestana;
  final Color nivelBorde;
  final Color nivelTinte;
  final List<Color> boton;
  final Color botonSombra;
  final Color botonTexto;
  final Color insigniaBorde;
  final Color insigniaTexto;

  /// Rótulo de la respuesta («Informe de campo», «Visión celestial»…).
  final Color rotulo;
  final Color casillaBorde;
  final Color casillaFondo;
  final Color casillaRotulo;
  final Color casillaValor;
  final Color temaPrevia;

  static const demeter = ModuloEstilo(
    icono: '🌱',
    sello: Color(0xFF84CC16),
    pestana: [Color.fromRGBO(132, 204, 22, .22), Color.fromRGBO(16, 185, 129, .14)],
    nivelBorde: Color.fromRGBO(163, 230, 53, .42),
    nivelTinte: Color.fromRGBO(132, 204, 22, .16),
    boton: [Color.fromRGBO(101, 163, 13, .95), Color.fromRGBO(16, 185, 129, .75)],
    botonSombra: Color.fromRGBO(22, 163, 74, .2),
    botonTexto: Color(0xFFF7FEE7),
    insigniaBorde: Color.fromRGBO(163, 230, 53, .28),
    insigniaTexto: Color.fromRGBO(190, 242, 100, .9),
    rotulo: Color.fromRGBO(163, 230, 53, .85),
    casillaBorde: Color.fromRGBO(132, 204, 22, .14),
    casillaFondo: Color.fromRGBO(132, 204, 22, .045),
    casillaRotulo: Color.fromRGBO(163, 230, 53, .6),
    casillaValor: Color(0xFFECFCCB),
    temaPrevia: Color.fromRGBO(163, 230, 53, .75),
  );

  static const oraculo = ModuloEstilo(
    icono: '🔮',
    sello: Color(0xFF4FD0E7),
    pestana: [Color.fromRGBO(99, 102, 241, .22), Color.fromRGBO(34, 211, 238, .14)],
    nivelBorde: Color.fromRGBO(103, 232, 249, .42),
    nivelTinte: Color.fromRGBO(99, 102, 241, .16),
    boton: [Color.fromRGBO(99, 102, 241, .92), Color.fromRGBO(34, 211, 238, .7)],
    botonSombra: Color.fromRGBO(79, 70, 229, .22),
    botonTexto: Color(0xFFEEF2FF),
    insigniaBorde: Color.fromRGBO(129, 140, 248, .28),
    insigniaTexto: Color.fromRGBO(165, 180, 252, .9),
    rotulo: Color.fromRGBO(165, 180, 252, .8),
    casillaBorde: Color.fromRGBO(99, 102, 241, .16),
    casillaFondo: Color.fromRGBO(99, 102, 241, .05),
    casillaRotulo: Color.fromRGBO(165, 180, 252, .62),
    casillaValor: Color(0xFFE0E7FF),
    temaPrevia: Color.fromRGBO(103, 232, 249, .7),
  );

  static const persefone = ModuloEstilo(
    icono: '💞',
    sello: Color(0xFFF0ABFC),
    pestana: [Color.fromRGBO(236, 72, 153, .22), Color.fromRGBO(190, 24, 93, .16)],
    nivelBorde: Color.fromRGBO(244, 114, 182, .42),
    nivelTinte: Color.fromRGBO(236, 72, 153, .16),
    boton: [Color.fromRGBO(236, 72, 153, .9), Color.fromRGBO(190, 24, 93, .85)],
    botonSombra: Color.fromRGBO(236, 72, 153, .2),
    botonTexto: Color(0xFFFFF1F2),
    insigniaBorde: Color.fromRGBO(244, 114, 182, .28),
    insigniaTexto: Color.fromRGBO(249, 168, 212, .9),
    rotulo: Color.fromRGBO(244, 114, 182, .85),
    casillaBorde: Color.fromRGBO(244, 114, 182, .16),
    casillaFondo: Color.fromRGBO(236, 72, 153, .05),
    casillaRotulo: Color.fromRGBO(249, 168, 212, .62),
    casillaValor: Color(0xFFFCE7F3),
    temaPrevia: Color.fromRGBO(249, 168, 212, .75),
  );

  static const notaIa = ModuloEstilo(
    icono: '📜',
    sello: Color(0xFFF5D76E),
    pestana: [Color.fromRGBO(245, 215, 110, .22), Color.fromRGBO(245, 215, 110, .1)],
    nivelBorde: Color.fromRGBO(245, 215, 110, .42),
    nivelTinte: Color.fromRGBO(245, 215, 110, .16),
    boton: [Color.fromRGBO(245, 215, 110, .9), Color.fromRGBO(217, 119, 6, .8)],
    botonSombra: Color.fromRGBO(245, 215, 110, .2),
    botonTexto: Color(0xFF1C1917),
    insigniaBorde: Color.fromRGBO(245, 215, 110, .28),
    insigniaTexto: Color.fromRGBO(253, 230, 138, .9),
    rotulo: Color.fromRGBO(253, 230, 138, .85),
    casillaBorde: Color.fromRGBO(245, 215, 110, .16),
    casillaFondo: Color.fromRGBO(245, 215, 110, .05),
    casillaRotulo: Color.fromRGBO(253, 230, 138, .62),
    casillaValor: Color(0xFFFEF3C7),
    temaPrevia: Color.fromRGBO(253, 230, 138, .75),
  );
}

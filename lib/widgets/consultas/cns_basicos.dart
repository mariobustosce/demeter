import 'package:flutter/material.dart';

import '../../textos/consultas_textos.dart';
import '../../theme/consultas_theme.dart';

/// El «select» de la consola (`.cns-select`): muestra el valor elegido y abre
/// una hoja al tocarlo.
class CnsCampo extends StatelessWidget {
  const CnsCampo({
    super.key,
    required this.texto,
    required this.onTap,
    this.vacio = false,
    this.compacto = false,
    this.etiquetaSemantica,
  });

  final String texto;
  final VoidCallback? onTap;
  final bool vacio;
  final bool compacto;
  final String? etiquetaSemantica;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: etiquetaSemantica,
      child: Material(
        color: CnsColores.pozoHondo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compacto ? 13 : CnsRadios.tarjeta),
          side: BorderSide(color: CnsColores.slate(.16)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compacto ? 13 : 16, vertical: compacto ? 11 : 15),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    texto,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compacto ? 12.8 : 13.8,
                      height: 1.4,
                      color: vacio ? CnsColores.slate(.7) : CnsColores.texto,
                    ),
                  ),
                ),
                const SizedBox(width: CnsEspacios.s),
                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: CnsColores.slate400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Caja con borde punteado (`.cns-note`, `.cns-preview`, `.cns-empty`).
class CnsPunteado extends StatelessWidget {
  const CnsPunteado({
    super.key,
    required this.child,
    this.fondo = CnsColores.pozo,
    this.radio = CnsRadios.tarjeta,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final Color fondo;
  final double radio;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BordePunteado(color: CnsColores.slate(.18), radio: radio),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(radio)),
        child: child,
      ),
    );
  }
}

class _BordePunteado extends CustomPainter {
  _BordePunteado({required this.color, required this.radio});

  final Color color;
  final double radio;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final borde = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radio)));
    for (final tramo in borde.computeMetrics()) {
      for (var d = 0.0; d < tramo.length; d += 7) {
        canvas.drawPath(tramo.extractPath(d, d + 3.5), pincel);
      }
    }
  }

  @override
  bool shouldRepaint(_BordePunteado old) => old.color != color || old.radio != radio;
}

/// Una opción de [mostrarOpciones].
class OpcionHoja<T> {
  const OpcionHoja(this.valor, this.texto, {this.habilitada = true, this.detalle});

  final T valor;
  final String texto;
  final bool habilitada;
  final String? detalle;
}

/// Una sección de [mostrarOpciones] (las preguntas van agrupadas por tema).
class SeccionHoja<T> {
  const SeccionHoja(this.titulo, this.opciones);

  final String? titulo;
  final List<OpcionHoja<T>> opciones;
}

/// La hoja inferior de la consola: oscura, con secciones y la opción elegida
/// marcada. Devuelve la elegida o `null` si se cierra.
Future<T?> mostrarOpciones<T>(
  BuildContext context, {
  required String titulo,
  required List<SeccionHoja<T>> secciones,
  T? elegida,
  ModuloEstilo estilo = ModuloEstilo.oraculo,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: CnsColores.hoja,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(CnsRadios.resumen))),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      maxChildSize: .92,
      minChildSize: .4,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(CnsEspacios.l, CnsEspacios.m, CnsEspacios.l, CnsEspacios.xxl),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: CnsColores.slate(.3), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: CnsEspacios.l),
          Text(titulo.toUpperCase(), style: CnsTipos.cejilla(size: 10, tracking: .24)),
          for (final seccion in secciones) ...[
            if (seccion.titulo != null)
              Padding(
                padding: const EdgeInsets.only(top: CnsEspacios.l + 4, bottom: CnsEspacios.s),
                child: Text(seccion.titulo!, style: CnsTipos.serifStyle(size: 15, color: CnsColores.textoFuerte)),
              )
            else
              const SizedBox(height: CnsEspacios.s),
            for (final o in seccion.opciones)
              _FilaOpcion<T>(opcion: o, elegida: o.valor == elegida, estilo: estilo),
          ],
        ],
      ),
    ),
  );
}

class _FilaOpcion<T> extends StatelessWidget {
  const _FilaOpcion({required this.opcion, required this.elegida, required this.estilo});

  final OpcionHoja<T> opcion;
  final bool elegida;
  final ModuloEstilo estilo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: elegida ? estilo.nivelTinte : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CnsRadios.casilla),
          side: BorderSide(color: elegida ? estilo.nivelBorde : CnsColores.slate(.1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: opcion.habilitada ? () => Navigator.of(context).pop(opcion.valor) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    opcion.detalle == null ? opcion.texto : '${opcion.texto} · ${opcion.detalle}',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: opcion.habilitada ? CnsColores.texto : CnsColores.slate(.45),
                    ),
                  ),
                ),
                if (elegida) Icon(Icons.check_rounded, size: 18, color: estilo.rotulo),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El texto de un SnackBar como `.cns-toast`: oscuro y redondeado.
void avisoConsola(BuildContext context, String mensaje, {SnackBarAction? accion, bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(mensaje, style: TextStyle(fontSize: 13.3, color: error ? CnsColores.error : CnsColores.texto)),
      action: accion,
      behavior: SnackBarBehavior.floating,
      backgroundColor: CnsColores.toast,
      elevation: 12,
      margin: const EdgeInsets.all(CnsEspacios.l),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CnsRadios.tarjeta),
        side: BorderSide(color: CnsColores.slate(.18)),
      ),
      duration: const Duration(seconds: 3),
    ));
}

// ── Fechas ───────────────────────────────────────────────────────────────────

String _dos(int n) => n.toString().padLeft(2, '0');

/// `05 Nov 2026`, como `d M Y` en la web.
String fechaCorta(DateTime f) => '${_dos(f.day)} ${TxConsultas.meses[f.month - 1]} ${f.year}';

String horaCorta(DateTime f) => '${_dos(f.hour)}:${_dos(f.minute)}';

/// `05/11/2026 14:30`.
String fechaHora(DateTime f) => '${_dos(f.day)}/${_dos(f.month)}/${f.year} ${horaCorta(f)}';

/// «hace 3 horas», como diffForHumans.
String haceTiempo(DateTime f, {DateTime? ahora}) {
  final d = (ahora ?? DateTime.now()).difference(f);
  String de(int n, String uno, String varios) => 'hace $n ${n == 1 ? uno : varios}';
  if (d.inMinutes < 1) return 'hace unos segundos';
  if (d.inHours < 1) return de(d.inMinutes, 'minuto', 'minutos');
  if (d.inDays < 1) return de(d.inHours, 'hora', 'horas');
  if (d.inDays < 7) return de(d.inDays, 'día', 'días');
  if (d.inDays < 30) return de(d.inDays ~/ 7, 'semana', 'semanas');
  if (d.inDays < 365) return de(d.inDays ~/ 30, 'mes', 'meses');
  return de(d.inDays ~/ 365, 'año', 'años');
}

/// `1,2 s` como en la web (con coma decimal).
String segundos(int ms, {int decimales = 1}) => '${(ms / 1000).toStringAsFixed(decimales).replaceAll('.', ',')} s';

/// Miles con punto: `1.234`.
String miles(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

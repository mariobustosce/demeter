import 'package:flutter/material.dart';

import '../../models/consultas.dart';
import '../../theme/consultas_theme.dart';

/// La franja de 5 casillas: clima en Demeter, cielo en el Oráculo. En
/// teléfono va en rejilla de 2 y la quinta cruza el ancho.
class FranjaDatos extends StatelessWidget {
  const FranjaDatos({super.key, required this.casillas, required this.estilo});

  final List<CasillaFranja> casillas;
  final ModuloEstilo estilo;

  @override
  Widget build(BuildContext context) {
    if (casillas.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, c) {
      const gap = CnsEspacios.s;
      final ancha = c.maxWidth >= CnsEspacios.anchoFranjaAncha;
      final columnas = ancha ? casillas.length : 2;
      final ancho = (c.maxWidth - gap * (columnas - 1)) / columnas;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final (i, casilla) in casillas.indexed)
            SizedBox(
              // Impar en dos columnas: la última ocupa la fila entera.
              width: !ancha && i == casillas.length - 1 && casillas.length.isOdd ? c.maxWidth : ancho,
              child: _Casilla(casilla: casilla, estilo: estilo),
            ),
        ],
      );
    });
  }
}

class _Casilla extends StatelessWidget {
  const _Casilla({required this.casilla, required this.estilo});

  final CasillaFranja casilla;
  final ModuloEstilo estilo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: estilo.casillaFondo,
        borderRadius: BorderRadius.circular(CnsRadios.casilla),
        border: Border.all(color: estilo.casillaBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            casilla.rotulo.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CnsTipos.cejilla(size: 9, tracking: .16, color: estilo.casillaRotulo, weight: FontWeight.w500),
          ),
          const SizedBox(height: 5),
          Text(
            casilla.valor,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorDeSigno(casilla.color) ?? estilo.casillaValor,
            ),
          ),
          if (casilla.nota != null) ...[
            const SizedBox(height: 2),
            Text(casilla.nota!, style: TextStyle(fontSize: 10.5, color: CnsColores.slate(.6))),
          ],
        ],
      ),
    );
  }
}

/// `#rrggbb` → Color, o `null` si no se entiende.
Color? colorDeSigno(String? hex) {
  if (hex == null) return null;
  final limpio = hex.replaceFirst('#', '');
  if (limpio.length != 6) return null;
  final v = int.tryParse(limpio, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

import 'package:flutter/material.dart';

import '../../models/consultas.dart';
import '../../theme/consultas_theme.dart';

/// Una tarjeta de nivel (`.cns-level`). La elegida sube 2 px y toma el borde
/// y el degradado de su módulo.
class NivelCard extends StatelessWidget {
  const NivelCard({
    super.key,
    required this.nivel,
    required this.elegido,
    required this.estilo,
    required this.onTap,
  });

  final NivelConsulta nivel;
  final bool elegido;
  final ModuloEstilo estilo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sinAnimar = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      selected: elegido,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: sinAnimar ? Duration.zero : CnsDuraciones.nivel,
          transform: Matrix4.translationValues(0, elegido ? -2 : 0, 0),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CnsRadios.tarjeta),
            border: Border.all(color: elegido ? estilo.nivelBorde : CnsColores.slate(.12)),
            color: elegido ? null : CnsColores.pozo,
            gradient: elegido
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [estilo.nivelTinte, CnsColores.caja],
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nivel.nombre.toUpperCase(),
                      style: CnsTipos.cejilla(
                        size: 11,
                        tracking: .14,
                        weight: FontWeight.w700,
                        color: CnsColores.texto.withValues(alpha: .82),
                      ),
                    ),
                  ),
                  Text(
                    '${nivel.costo} ✨',
                    style: TextStyle(
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: CnsColores.ambar.withValues(alpha: .85),
                    ),
                  ),
                ],
              ),
              if (nivel.descripcion.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(nivel.descripcion, style: TextStyle(fontSize: 11.5, height: 1.5, color: CnsColores.slate(.68))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Los tres niveles: en columna en el teléfono, en fila desde tableta.
class NivelesConsulta extends StatelessWidget {
  const NivelesConsulta({
    super.key,
    required this.niveles,
    required this.elegido,
    required this.estilo,
    required this.onElegir,
  });

  final List<NivelConsulta> niveles;
  final String elegido;
  final ModuloEstilo estilo;
  final ValueChanged<String> onElegir;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final tarjetas = [
        for (final n in niveles)
          NivelCard(nivel: n, elegido: n.clave == elegido, estilo: estilo, onTap: () => onElegir(n.clave)),
      ];
      if (c.maxWidth < 560) {
        return Column(
          children: [
            for (final (i, t) in tarjetas.indexed) ...[if (i > 0) const SizedBox(height: 10), t],
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, t) in tarjetas.indexed) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: t)],
          ],
        ),
      );
    });
  }
}

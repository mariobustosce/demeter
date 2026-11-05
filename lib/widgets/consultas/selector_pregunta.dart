import 'package:flutter/material.dart';

import '../../models/consultas.dart';
import '../../textos/consultas_textos.dart';
import '../../theme/consultas_theme.dart';
import 'cns_basicos.dart';

/// El selector de pregunta: un campo que abre una hoja con las preguntas
/// agrupadas por tema, cada grupo con su icono.
class SelectorPregunta extends StatelessWidget {
  const SelectorPregunta({
    super.key,
    required this.grupos,
    required this.elegida,
    required this.estilo,
    required this.onElegir,
  });

  final List<GrupoPreguntas> grupos;
  final String? elegida;
  final ModuloEstilo estilo;
  final ValueChanged<String> onElegir;

  @override
  Widget build(BuildContext context) {
    return CnsCampo(
      key: const ValueKey('selector-pregunta'),
      texto: elegida ?? TxConsultas.eligeConsulta,
      vacio: elegida == null,
      onTap: () async {
        final pregunta = await mostrarOpciones<String>(
          context,
          titulo: TxConsultas.eligeConsulta,
          estilo: estilo,
          elegida: elegida,
          secciones: [
            for (final g in grupos)
              SeccionHoja('${g.icono} ${g.titulo}', [for (final p in g.preguntas) OpcionHoja(p, p)]),
          ],
        );
        if (pregunta != null) onElegir(pregunta);
      },
    );
  }
}

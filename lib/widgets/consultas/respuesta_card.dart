import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../theme/consultas_theme.dart';

/// La respuesta bajo el panel (`.cns-response`): rótulo del módulo, botón
/// para limpiarla y el cuerpo en Markdown en una caja oscura.
class RespuestaCard extends StatelessWidget {
  const RespuestaCard({
    super.key,
    required this.rotulo,
    required this.texto,
    required this.estilo,
    required this.cerrar,
    required this.onCerrar,
  });

  final String rotulo;
  final String texto;
  final ModuloEstilo estilo;
  final String cerrar;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(rotulo.toUpperCase(), style: CnsTipos.cejilla(size: 10, tracking: .22, color: estilo.rotulo)),
            ),
            TextButton(
              onPressed: onCerrar,
              style: TextButton.styleFrom(foregroundColor: CnsColores.slate(.6), visualDensity: VisualDensity.compact),
              child: Text(cerrar.toUpperCase(), style: CnsTipos.cejilla(size: 10, tracking: .16)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: CnsColores.caja,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: CnsColores.slate(.14)),
          ),
          child: CuerpoMarkdown(texto: texto),
        ),
      ],
    );
  }
}

/// El texto de la IA en Markdown, con el interlineado amplio de la web.
class CuerpoMarkdown extends StatelessWidget {
  const CuerpoMarkdown({super.key, required this.texto, this.size = 14});

  final String texto;
  final double size;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: size, height: 1.75, color: CnsColores.texto.withValues(alpha: .92));
    return MarkdownBody(
      data: texto,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: base,
        listBullet: base,
        strong: base.copyWith(fontWeight: FontWeight.w700, color: CnsColores.titulo),
        em: base.copyWith(fontStyle: FontStyle.italic),
        h1: CnsTipos.serifStyle(size: size + 6),
        h2: CnsTipos.serifStyle(size: size + 4),
        h3: CnsTipos.serifStyle(size: size + 2),
        blockquote: base.copyWith(color: CnsColores.slate300),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: CnsColores.slate(.3), width: 2)),
        ),
        horizontalRuleDecoration: BoxDecoration(border: Border(top: BorderSide(color: CnsColores.slate(.14)))),
        pPadding: const EdgeInsets.only(bottom: 4),
      ),
    );
  }
}

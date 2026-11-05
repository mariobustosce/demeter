import 'package:flutter/material.dart';

import '../../textos/consultas_textos.dart';
import '../../theme/consultas_theme.dart';
import 'cns_basicos.dart';

/// La pregunta elegida antes de enviarla (`.cns-preview`): tema en
/// mayúsculas y la pregunta en serif cursiva.
class VistaPrevia extends StatelessWidget {
  const VistaPrevia({super.key, required this.pregunta, required this.tema, required this.estilo});

  final String? pregunta;
  final String? tema;
  final ModuloEstilo estilo;

  @override
  Widget build(BuildContext context) {
    final vacia = (pregunta ?? '').isEmpty;
    return CnsPunteado(
      fondo: CnsColores.brilloTenue,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (vacia ? TxConsultas.sinSeleccionar : (tema ?? TxConsultas.demeterResumenConsulta)).toUpperCase(),
            style: CnsTipos.cejilla(size: 10, tracking: .18, color: estilo.temaPrevia, weight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          if (vacia)
            Text(TxConsultas.previewVacio, style: TextStyle(fontSize: 13.5, color: CnsColores.slate(.55)))
          else
            Text(
              pregunta!,
              style: CnsTipos.serifStyle(
                size: 17,
                style: FontStyle.italic,
                height: 1.5,
                color: CnsColores.textoFuerte.withValues(alpha: .92),
              ),
            ),
        ],
      ),
    );
  }
}

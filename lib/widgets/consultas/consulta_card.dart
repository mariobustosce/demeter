import 'package:flutter/material.dart';

import '../../models/consultas.dart';
import '../../textos/consultas_textos.dart';
import '../../theme/consultas_theme.dart';
import 'cns_basicos.dart';
import 'modulo_badge.dart';

/// Una consulta del historial (`.cns-card`): fecha e insignia, la pregunta en
/// serif, un extracto de la respuesta, hasta 3 planetas y el pie.
class ConsultaCard extends StatelessWidget {
  const ConsultaCard({super.key, required this.consulta, required this.onAbrir, this.onBorrar});

  final Consulta consulta;
  final VoidCallback onAbrir;
  final VoidCallback? onBorrar;

  @override
  Widget build(BuildContext context) {
    final c = consulta;
    final planetas = c.planetas;
    final cuando = c.creada == null ? '' : '${fechaCorta(c.creada!)} · ${horaCorta(c.creada!)}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAbrir,
        onLongPress: onBorrar,
        borderRadius: BorderRadius.circular(CnsRadios.resumen),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CnsRadios.resumen),
            border: Border.all(color: CnsColores.slate(.1)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [CnsColores.tarjetaA, CnsColores.tarjetaB],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      cuando.toUpperCase(),
                      style: CnsTipos.cejilla(size: 10, tracking: .18, color: CnsColores.slate(.55), weight: FontWeight.w500),
                    ),
                  ),
                  ModuloBadge(modulo: c.modulo),
                  if (onBorrar != null)
                    SizedBox(
                      width: 32,
                      height: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 17,
                        tooltip: TxConsultas.borrar,
                        icon: Icon(Icons.delete_outline_rounded, color: CnsColores.slate(.5)),
                        onPressed: onBorrar,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                c.pregunta,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: CnsTipos.serifStyle(size: 16.5, height: 1.4),
              ),
              const SizedBox(height: 10),
              Text(
                extracto(c.respuesta),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, height: 1.65, color: CnsColores.slate(.78)),
              ),
              if (planetas.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in planetas.take(3)) _Chip(p),
                    if (planetas.length > 3) _Chip('+${planetas.length - 3}'),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: CnsColores.slate(.08)))),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '⏱ ${c.tiempoMs == null ? TxConsultas.nd : segundos(c.tiempoMs!)}',
                        style: TextStyle(fontSize: 11, color: CnsColores.slate(.55)),
                      ),
                    ),
                    Text(
                      '${TxConsultas.leerDetalle} →',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .9,
                        color: CnsColores.cianClaro.withValues(alpha: .85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// El texto sin las marcas de Markdown, como el strip_tags de la web.
  static String extracto(String texto) => texto
      .replaceAll(RegExp(r'[#*_>`~]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _Chip extends StatelessWidget {
  const _Chip(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CnsRadios.pildora),
        border: Border.all(color: CnsColores.cianClaro.withValues(alpha: .18)),
        color: CnsColores.cianClaro.withValues(alpha: .06),
      ),
      child: Text(texto, style: const TextStyle(fontSize: 10, color: CnsColores.chipTexto)),
    );
  }
}

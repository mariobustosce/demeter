import 'package:flutter/material.dart';

import '../../theme/consultas_theme.dart';

/// Un paso de la consola (`.cns-step`): `01` en serif cian, título y pista.
class PasoNumerado extends StatelessWidget {
  const PasoNumerado({
    super.key,
    required this.numero,
    required this.titulo,
    required this.pista,
    required this.child,
  });

  final int numero;
  final String titulo;
  final String pista;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                numero.toString().padLeft(2, '0'),
                style: CnsTipos.serifStyle(size: 12, color: CnsColores.cianClaro.withValues(alpha: .65))
                    .copyWith(letterSpacing: 1.2),
              ),
            ),
            const SizedBox(width: CnsEspacios.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CnsColores.textoFuerte)),
                  const SizedBox(height: 3),
                  Text(pista, style: TextStyle(fontSize: 12, height: 1.4, color: CnsColores.slate(.62))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        child,
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/consultas_theme.dart';
import 'modulo_tabs.dart';

/// La insignia del módulo en las tarjetas del historial (`.cns-badge`).
class ModuloBadge extends StatelessWidget {
  const ModuloBadge({super.key, required this.modulo});

  final ModuloConsulta modulo;

  @override
  Widget build(BuildContext context) {
    final estilo = modulo.estilo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CnsRadios.pildora),
        border: Border.all(color: estilo.insigniaBorde),
      ),
      child: Text(
        ModuloTabs.nombre(modulo).toUpperCase(),
        style: CnsTipos.cejilla(size: 9, tracking: .12, color: estilo.insigniaTexto),
      ),
    );
  }
}

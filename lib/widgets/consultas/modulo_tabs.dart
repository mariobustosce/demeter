import 'package:flutter/material.dart';

import '../../textos/consultas_textos.dart';
import '../../theme/consultas_theme.dart';

/// Las tres pestañas de la consola (`.cns-tabs`), en el orden de la web:
/// Demeter, Oráculo y Perséfone. La activa lleva el degradado de su módulo.
class ModuloTabs extends StatelessWidget {
  const ModuloTabs({super.key, required this.activo, required this.onCambio});

  final ModuloConsulta activo;
  final ValueChanged<ModuloConsulta> onCambio;

  static String nombre(ModuloConsulta m) => switch (m) {
        ModuloConsulta.demeter => TxConsultas.moduloDemeter,
        ModuloConsulta.oraculo => TxConsultas.moduloOraculo,
        ModuloConsulta.persefone => TxConsultas.moduloPersefone,
        ModuloConsulta.notaIa => TxConsultas.moduloNombreNotaIa,
      };

  @override
  Widget build(BuildContext context) {
    final telefono = MediaQuery.sizeOf(context).width < CnsEspacios.anchoTelefono;
    return Container(
      padding: const EdgeInsets.all(CnsEspacios.s),
      decoration: BoxDecoration(
        color: CnsColores.velo,
        border: Border(bottom: BorderSide(color: CnsColores.slate(.1))),
      ),
      child: Row(
        children: [
          for (final (i, m) in ModuloConsulta.consola.indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _Tab(modulo: m, activa: m == activo, telefono: telefono, onTap: () => onCambio(m))),
          ],
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.modulo, required this.activa, required this.telefono, required this.onTap});

  final ModuloConsulta modulo;
  final bool activa;
  final bool telefono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = telefono ? 9.5 : 11.0;
    return Semantics(
      selected: activa,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: CnsDuraciones.nivel,
          padding: EdgeInsets.symmetric(vertical: telefono ? 12 : 14, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CnsRadios.casilla),
            gradient: activa
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: modulo.estilo.pestana,
                  )
                : null,
            border: Border.all(color: activa ? CnsColores.slate(.14) : Colors.transparent),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              ModuloTabs.nombre(modulo).toUpperCase(),
              maxLines: 1,
              style: CnsTipos.cejilla(
                size: size,
                tracking: telefono ? .06 : .14,
                color: activa ? CnsColores.titulo : CnsColores.slate(.66),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

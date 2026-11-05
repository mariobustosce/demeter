import 'package:flutter/material.dart';

import '../../models/consultas.dart';
import '../../textos/consultas_textos.dart';
import '../../theme/consultas_theme.dart';
import 'cns_basicos.dart';

/// El resumen de la consulta (`.cns-aside`): filas clave/valor, costo, tokens,
/// el botón del módulo, el selector de IA y la nota al pie. En el teléfono va
/// debajo de los pasos y no queda fijo.
class ResumenConsulta extends StatelessWidget {
  const ResumenConsulta({
    super.key,
    required this.estilo,
    required this.filas,
    required this.costo,
    required this.lineaTokens,
    required this.boton,
    required this.habilitado,
    required this.cargando,
    required this.textoCargando,
    required this.onConsultar,
    required this.proveedores,
    required this.proveedor,
    required this.onProveedor,
  });

  final ModuloEstilo estilo;
  final List<(String, String)> filas;
  final int costo;

  /// «~ 140 tokens estimados», o la nota de Perséfone.
  final String lineaTokens;
  final String boton;
  final bool habilitado;
  final bool cargando;
  final String textoCargando;
  final VoidCallback onConsultar;
  final List<ProveedorIa> proveedores;
  final String? proveedor;
  final ValueChanged<String> onProveedor;

  @override
  Widget build(BuildContext context) {
    final elegido = proveedores.where((p) => p.clave == proveedor).firstOrNull;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CnsRadios.resumen),
        border: Border.all(color: CnsColores.slate(.14)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [CnsColores.resumenA, CnsColores.resumenB],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(TxConsultas.resumen.toUpperCase(), style: CnsTipos.cejilla(size: 10, tracking: .24)),
          const SizedBox(height: 4),
          for (final (clave, valor) in filas) _Fila(clave: clave, valor: valor),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(TxConsultas.costo.toUpperCase(), style: CnsTipos.cejilla(size: 10, tracking: .2)),
              ),
              Text(
                '$costo ✨',
                key: const ValueKey('resumen-costo'),
                style: const TextStyle(
                  fontSize: 29,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: CnsColores.ambar,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            lineaTokens,
            key: const ValueKey('resumen-tokens'),
            style: TextStyle(fontSize: 11, color: CnsColores.slate(.55)),
          ),
          const SizedBox(height: 18),
          _BotonConsultar(
            estilo: estilo,
            texto: boton,
            habilitado: habilitado && !cargando,
            cargando: cargando,
            textoCargando: textoCargando,
            onTap: onConsultar,
          ),
          const SizedBox(height: 14),
          Text(TxConsultas.inteligenciaArtificial.toUpperCase(), style: CnsTipos.cejilla(size: 10, tracking: .2)),
          const SizedBox(height: 6),
          CnsCampo(
            compacto: true,
            texto: elegido?.etiqueta ?? proveedor ?? '—',
            onTap: proveedores.isEmpty
                ? null
                : () async {
                    final clave = await mostrarOpciones<String>(
                      context,
                      titulo: TxConsultas.inteligenciaArtificial,
                      estilo: estilo,
                      elegida: proveedor,
                      secciones: [
                        SeccionHoja(null, [
                          for (final p in proveedores)
                            OpcionHoja(
                              p.clave,
                              p.etiqueta,
                              habilitada: p.disponible,
                              detalle: p.disponible ? null : TxConsultas.noConfigurada,
                            ),
                        ]),
                      ],
                    );
                    if (clave != null) onProveedor(clave);
                  },
          ),
          const SizedBox(height: 14),
          Text(
            TxConsultas.notaPie,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, height: 1.4, color: CnsColores.slate(.55)),
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.clave, required this.valor});

  final String clave;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: CnsColores.slate(.08)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(clave, style: TextStyle(fontSize: 12, color: CnsColores.slate(.6))),
          const SizedBox(width: CnsEspacios.l),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, height: 1.4, color: CnsColores.textoFuerte.withValues(alpha: .88)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonConsultar extends StatelessWidget {
  const _BotonConsultar({
    required this.estilo,
    required this.texto,
    required this.habilitado,
    required this.cargando,
    required this.textoCargando,
    required this.onTap,
  });

  final ModuloEstilo estilo;
  final String texto;
  final bool habilitado;
  final bool cargando;
  final String textoCargando;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final etiqueta = Text(
      (cargando ? textoCargando : texto).toUpperCase(),
      style: CnsTipos.cejilla(size: 11, tracking: .16, weight: FontWeight.w700, color: estilo.botonTexto),
    );
    return Semantics(
      button: true,
      enabled: habilitado,
      child: Opacity(
        opacity: habilitado || cargando ? 1 : .45,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CnsRadios.boton),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: estilo.boton),
            boxShadow: habilitado ? [BoxShadow(color: estilo.botonSombra, blurRadius: 28, offset: const Offset(0, 12))] : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: const ValueKey('boton-consultar'),
              borderRadius: BorderRadius.circular(CnsRadios.boton),
              onTap: habilitado ? onTap : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (cargando) ...[
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: estilo.botonTexto),
                      ),
                      const SizedBox(width: 9),
                    ],
                    Flexible(child: etiqueta),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

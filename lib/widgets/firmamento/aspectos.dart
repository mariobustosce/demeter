import 'package:flutter/material.dart';

import '../../models/firmamento.dart';
import 'tablas.dart';

/// Aspectos del firmamento: chips de filtro por tipo y un conmutador entre la
/// lista (por grupo) y la grilla (aspectario triangular). Tocar un aspecto
/// llama a [onPar] para resaltarlo en la rueda.
class AspectosFirmamento extends StatefulWidget {
  const AspectosFirmamento({super.key, required this.firmamento, this.par, this.onPar});

  final Firmamento firmamento;
  final (String, String)? par;
  final void Function(String a, String b)? onPar;

  @override
  State<AspectosFirmamento> createState() => _AspectosFirmamentoState();
}

class _AspectosFirmamentoState extends State<AspectosFirmamento> {
  final Set<String> _apagados = {};
  bool _grilla = false;

  Firmamento get f => widget.firmamento;

  List<Aspecto> get _visibles =>
      [for (final a in f.aspectos) if (!_apagados.contains(a.tipo)) a];

  bool _elegido(Aspecto a) => widget.par != null && a.une(widget.par!.$1, widget.par!.$2);

  @override
  Widget build(BuildContext context) {
    if (f.aspectos.isEmpty) {
      return const Text('Sin aspectos guardados en este firmamento.',
          style: TextStyle(color: kTextoTenue, fontSize: 13));
    }

    // Un chip por tipo, en el orden en que aparecen.
    final tipos = <String, ({Aspecto muestra, int n})>{};
    for (final a in f.aspectos) {
      final t = tipos[a.tipo];
      tipos[a.tipo] = (muestra: t?.muestra ?? a, n: (t?.n ?? 0) + 1);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Conmutador(texto: 'Lista', activo: !_grilla, onTap: () => setState(() => _grilla = false)),
            const SizedBox(width: 6),
            _Conmutador(texto: 'Grilla', activo: _grilla, onTap: () => setState(() => _grilla = true)),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in tipos.entries)
              _ChipTipo(
                aspecto: e.value.muestra,
                n: e.value.n,
                encendido: !_apagados.contains(e.key),
                onTap: () => setState(() {
                  if (!_apagados.remove(e.key)) _apagados.add(e.key);
                }),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_grilla) _buildGrilla() else _buildLista(),
        const SizedBox(height: 8),
        const Text(
          'Orbe al aspecto exacto · a aplicativo, s separativo · con borde, los de orbe menor a 1°.',
          style: TextStyle(color: kTextoTenue, fontSize: 11, height: 1.35),
        ),
      ],
    );
  }

  Widget _buildLista() {
    final visibles = _visibles;
    Widget grupo(String clave, String titulo, {bool abierto = true}) {
      final lista = [for (final a in visibles) if (a.grupo == clave) a];
      if (lista.isEmpty) return const SizedBox.shrink();
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('aspectos-$clave'),
          initiallyExpanded: abierto,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          iconColor: kTextoTenue,
          collapsedIconColor: kTextoTenue,
          title: Text('$titulo · ${lista.length}',
              style: const TextStyle(color: kVioleta, fontWeight: FontWeight.bold, fontSize: 13)),
          children: [for (final a in lista) _fila(a)],
        ),
      );
    }

    return Column(
      children: [
        grupo('mayores', 'Mayores'),
        grupo('ejes', 'A los ángulos'),
        grupo('menores', 'Menores', abierto: false),
      ],
    );
  }

  Widget _fila(Aspecto a) {
    final elegido = _elegido(a);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: elegido ? a.color.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.03),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: a.orbe < 1 ? kCian.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => widget.onPar?.call(a.a, a.b),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: glifoTexto(f.simbolo(a.a)), style: TextStyle(color: f.color(a.a))),
                      TextSpan(text: ' ${glifoTexto(a.simbolo)} ', style: TextStyle(color: a.color)),
                      TextSpan(text: glifoTexto(f.simbolo(a.b)), style: TextStyle(color: f.color(a.b))),
                    ]),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${f.nombre(a.a)} ${a.nombre} ${f.nombre(a.b)}',
                    style: const TextStyle(color: kTexto, fontSize: 13),
                  ),
                ),
                Text(a.orbeDm, style: const TextStyle(color: kTexto, fontSize: 12)),
                SizedBox(
                  width: 16,
                  child: Text(a.aplicativo ? 'a' : 's',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: kTextoTenue, fontSize: 11)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Aspectario triangular: cuerpos en orden de efemérides, más AC y MC.
  Widget _buildGrilla() {
    final claves = [
      for (final c in f.cuerpos) c.clave,
      if (f.ejes.containsKey('asc')) 'asc',
      if (f.ejes.containsKey('mc')) 'mc',
    ];
    final visibles = _visibles;
    Aspecto? entre(String x, String y) {
      for (final a in visibles) {
        if (a.une(x, y)) return a;
      }
      return null;
    }

    const lado = 36.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < claves.length; i++)
            Row(
              children: [
                for (var j = 0; j < i; j++) _celda(entre(claves[i], claves[j]), lado),
                // La diagonal lleva el glifo del cuerpo de la fila.
                SizedBox(
                  width: lado,
                  height: lado,
                  child: Center(
                    child: Text(glifoTexto(f.simbolo(claves[i])),
                        style: TextStyle(color: f.color(claves[i]), fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _celda(Aspecto? a, double lado) {
    final borde = a != null && a.orbe < 1 ? kCian.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.06);
    return GestureDetector(
      onTap: a == null ? null : () => widget.onPar?.call(a.a, a.b),
      child: Container(
        width: lado,
        height: lado,
        decoration: BoxDecoration(
          color: a != null && _elegido(a) ? a.color.withValues(alpha: 0.15) : null,
          border: Border.all(color: borde, width: 0.6),
        ),
        child: a == null
            ? null
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(glifoTexto(a.simbolo), style: TextStyle(color: a.color, fontSize: 13, height: 1.1)),
                  Text('${a.orbeDm}${a.aplicativo ? 'a' : 's'}',
                      style: const TextStyle(color: kTextoTenue, fontSize: 7.5, height: 1.1)),
                ],
              ),
      ),
    );
  }
}

class _Conmutador extends StatelessWidget {
  const _Conmutador({required this.texto, required this.activo, required this.onTap});

  final String texto;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activo ? kCian.withValues(alpha: 0.2) : Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            texto,
            style: TextStyle(
              color: activo ? kCian : kTextoTenue,
              fontWeight: activo ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipTipo extends StatelessWidget {
  const _ChipTipo({required this.aspecto, required this.n, required this.encendido, required this.onTap});

  final Aspecto aspecto;
  final int n;
  final bool encendido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = encendido ? aspecto.color : kTextoTenue.withValues(alpha: 0.6);
    return Material(
      color: color.withValues(alpha: encendido ? 0.14 : 0.06),
      shape: StadiumBorder(side: BorderSide(color: color.withValues(alpha: 0.4))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            '${glifoTexto(aspecto.simbolo)} ${aspecto.nombre} · $n',
            style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

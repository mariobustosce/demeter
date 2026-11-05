import 'package:flutter/material.dart';

import '../../models/firmamento.dart';
import '../../services/api_client.dart';
import '../../services/astral_chart_service.dart';
import '../consultas/cns_basicos.dart' show haceTiempo;
import 'tablas.dart';

/// Notas y lectura IA del firmamento, como en la web: «+ Agregar» abre el
/// campo (250 como máximo) y la nota IA cobra polvo estelar tras confirmar.
/// Las nuevas van arriba; la de la IA ocupa el ancho y respeta sus saltos.
class NotasFirmamento extends StatefulWidget {
  const NotasFirmamento({
    super.key,
    required this.cartaId,
    required this.notas,
    required this.service,
    required this.onNota,
    this.costoIa,
  });

  final int cartaId;
  final List<NotaFirmamento> notas;
  final AstralChartService service;
  final ValueChanged<NotaFirmamento> onNota;

  /// Lo que cuesta la nota IA; sin él, el botón va sin precio.
  final int? costoIa;

  @override
  State<NotasFirmamento> createState() => _NotasFirmamentoState();
}

class _NotasFirmamentoState extends State<NotasFirmamento> {
  static const _maximo = 250;

  final TextEditingController _texto = TextEditingController();
  bool _abierto = false;
  bool _guardando = false;
  bool _consultando = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final contenido = _texto.text.trim();
    if (contenido.isEmpty || _guardando) return;
    setState(() => _guardando = true);
    try {
      final nota = await widget.service.agregarNota(widget.cartaId, contenido);
      if (!mounted) return;
      widget.onNota(nota);
      _texto.clear();
      setState(() => _abierto = false);
    } catch (e) {
      if (mounted) _avisar(e is ApiException ? e.message : 'No se pudo guardar');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _pedirIA() async {
    final costo = widget.costoIa;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xEF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nota astrológica IA', style: TextStyle(color: kTexto)),
        content: Text(
          costo == null || costo == 0
              ? 'Generar una nota astrológica con IA sobre este firmamento. ¿Continuar?'
              : 'Generar una nota astrológica con IA sobre este firmamento cuesta $costo de polvo '
                  'estelar. ¿Continuar?',
          style: const TextStyle(color: kTextoTenue, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: kTextoTenue)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Generar', style: TextStyle(color: kVioleta)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _consultando = true);
    try {
      final nota = await widget.service.notaIA(widget.cartaId);
      if (mounted) widget.onNota(nota);
    } catch (e) {
      // Sin saldo, la app ya abre la tienda; el mensaje dice cuánto falta.
      if (mounted) _avisar(e is ApiException ? e.message : 'No se pudo generar la nota');
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final costo = widget.costoIa;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Boton(
              key: const ValueKey('nota-agregar'),
              texto: '+ Agregar',
              color: kCian,
              onTap: _abierto ? null : () => setState(() => _abierto = true),
            ),
            _Boton(
              key: const ValueKey('nota-ia'),
              texto: _consultando
                  ? '🔮 Consultando…'
                  : '🔮 Nota astrológica IA${costo == null || costo == 0 ? '' : ' · $costo ✨'}',
              color: kVioleta,
              onTap: _consultando ? null : _pedirIA,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_abierto) ...[
          TextField(
            key: const ValueKey('nota-texto'),
            controller: _texto,
            autofocus: true,
            maxLength: _maximo,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(fontSize: 13.5, color: kTexto),
            decoration: InputDecoration(
              hintText: 'Una observación sobre este firmamento…',
              hintStyle: const TextStyle(fontSize: 13, color: kTextoTenue),
              counterStyle: const TextStyle(color: kTextoTenue),
              filled: true,
              fillColor: kFondo,
              border: _borde(Colors.white.withValues(alpha: 0.08)),
              enabledBorder: _borde(Colors.white.withValues(alpha: 0.08)),
              focusedBorder: _borde(kCian.withValues(alpha: 0.6)),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _guardando
                    ? null
                    : () => setState(() {
                          _abierto = false;
                          _texto.clear();
                        }),
                child: const Text('Cancelar', style: TextStyle(color: kTextoTenue)),
              ),
              const SizedBox(width: 4),
              TextButton(
                key: const ValueKey('nota-guardar'),
                onPressed: _guardando ? null : _guardar,
                child: Text(_guardando ? 'Guardando…' : 'Guardar', style: const TextStyle(color: kCian)),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (widget.notas.isEmpty)
          const Text(
            'Aún no hay notas en este firmamento.',
            style: TextStyle(color: kTextoTenue, fontSize: 12.5),
          )
        else
          for (final n in widget.notas) _Nota(n),
      ],
    );
  }

  OutlineInputBorder _borde(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color),
      );
}

class _Nota extends StatelessWidget {
  const _Nota(this.nota);

  final NotaFirmamento nota;

  @override
  Widget build(BuildContext context) {
    final color = nota.esIa ? kVioleta : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: nota.esIa ? kVioleta.withValues(alpha: 0.06) : kFondo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: nota.esIa ? 0.35 : 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (nota.esIa) ...[
            const Text(
              '🔮 Lectura IA',
              style: TextStyle(color: kVioleta, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
          ],
          Text(nota.contenido, style: const TextStyle(color: kTexto, fontSize: 13, height: 1.55)),
          if (nota.creada != null) ...[
            const SizedBox(height: 6),
            Text(haceTiempo(nota.creada!), style: const TextStyle(color: kTextoTenue, fontSize: 10.5)),
          ],
        ],
      ),
    );
  }
}

class _Boton extends StatelessWidget {
  const _Boton({super.key, required this.texto, required this.color, this.onTap});

  final String texto;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = onTap == null ? color.withValues(alpha: 0.5) : color;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: c,
        disabledForegroundColor: c,
        side: BorderSide(color: c.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(texto, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
    );
  }
}

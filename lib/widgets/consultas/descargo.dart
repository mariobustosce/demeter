import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../textos/consultas_textos.dart';
import '../../theme/consultas_theme.dart';

/// El descargo de la web (`<x-descargo />`, variante bloque): se cobra por
/// estas lecturas, así que va al pie de la consola.
class DescargoConsultas extends StatefulWidget {
  const DescargoConsultas({super.key});

  @override
  State<DescargoConsultas> createState() => _DescargoConsultasState();
}

class _DescargoConsultasState extends State<DescargoConsultas> {
  late final TapGestureRecognizer _enlace = TapGestureRecognizer()
    ..onTap = () => launchUrl(Uri.parse('$kWebBase/aviso-legal'), mode: LaunchMode.externalApplication);

  @override
  void dispose() {
    _enlace.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(fontSize: 13, height: 1.65, color: CnsColores.slate400);
    const fuerte = TextStyle(color: CnsColores.descargoFuerte, fontWeight: FontWeight.w700);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: CnsColores.descargoFondo,
        border: Border(left: BorderSide(color: CnsColores.descargoBorde, width: 3)),
        borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
      ),
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: TxConsultas.descargoAviso, style: fuerte),
            const TextSpan(text: TxConsultas.descargoAntes),
            const TextSpan(text: TxConsultas.descargoFuerte, style: fuerte),
            const TextSpan(text: TxConsultas.descargoDespues),
            TextSpan(
              text: TxConsultas.descargoEnlace,
              style: const TextStyle(color: CnsColores.enlace),
              recognizer: _enlace,
            ),
            const TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }
}

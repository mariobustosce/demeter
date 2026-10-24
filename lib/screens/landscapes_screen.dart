import 'package:flutter/material.dart';

import '../models/landscape.dart';
import '../services/api_client.dart';
import '../services/coin_balance.dart';
import '../services/landscapes_service.dart';
import '../widgets/landscape_grid.dart';

const _backgroundColor = Color(0xFF0A0A0F);
const _accentCyan = Color(0xFF4FD0E7);
const _textColor = Color(0xFFF7FAFC);
const _secondaryTextColor = Color(0xFF94A3B8);

/// «Mis paisajes»: el catálogo con su miniatura, y los premium con 🔒 y su
/// precio en polvo estelar. Mirar es libre; comprar desbloquea el paisaje para
/// todos los lugares. Cada lugar lo elige desde sus opciones en el mapa.
class LandscapesScreen extends StatefulWidget {
  const LandscapesScreen({super.key, this.service});

  final LandscapesService? service;

  @override
  State<LandscapesScreen> createState() => _LandscapesScreenState();
}

class _LandscapesScreenState extends State<LandscapesScreen> {
  late final LandscapesService _service = widget.service ?? LandscapesService();

  List<Landscape>? _landscapes;
  String? _error;
  String? _buying;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final landscapes = await _service.catalog();
      if (mounted) setState(() => _landscapes = landscapes);
    } on UnauthorizedException {
      // El ApiClient ya llevó al mapa de invitado.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('Paisajes no disponibles (${e.runtimeType}).');
      if (mounted) setState(() => _error = 'No se pudo cargar el catálogo.');
    }
  }

  Future<void> _buy(Landscape landscape) async {
    if (_buying != null || !await confirmLandscapePurchase(context, landscape)) return;
    if (!mounted) return;
    setState(() => _buying = landscape.key);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bought = await _service.buy(landscape.key);
      if (!mounted) return;
      setState(() => _landscapes = [
            for (final l in _landscapes ?? const <Landscape>[])
              l.key == bought.key ? bought : l,
          ]);
      messenger.showSnackBar(SnackBar(
        content: Text('¡Tuyo! «${landscape.title}» ya está desbloqueado para tus lugares.'),
        backgroundColor: Colors.green,
      ));
    } on UnauthorizedException {
      return;
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: Colors.redAccent,
      ));
      // Ya lo podía usar, o cambió el precio: el catálogo estaba viejo.
      if (e is ValidationException && mounted) await _load();
    } catch (e) {
      debugPrint('No se pudo comprar el paisaje (${e.runtimeType}).');
      messenger.showSnackBar(const SnackBar(
        content: Text('No se pudo completar la compra.'),
        backgroundColor: Colors.redAccent,
      ));
    } finally {
      if (mounted) setState(() => _buying = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        foregroundColor: _textColor,
        elevation: 0,
        title: const Text('Mis paisajes'),
        actions: [
          ValueListenableBuilder<int?>(
            valueListenable: coinBalance,
            builder: (context, coins, _) => coins == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Text(
                        '$coins ✨',
                        semanticsLabel: '$coins de Polvo Estelar',
                        style: const TextStyle(
                          color: _accentCyan,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: _accentCyan,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'El catálogo de paisajes para tus lugares favoritos. Para usar '
                'uno, abre las opciones de un lugar en el mapa y elige '
                '«Paisaje de este lugar».',
                style: TextStyle(color: _secondaryTextColor, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _content(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    final error = _error;
    final landscapes = _landscapes;
    if (error != null && landscapes == null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        text: error,
        action: TextButton(onPressed: _load, child: const Text('Reintentar')),
      );
    }
    if (landscapes == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(child: CircularProgressIndicator(color: _accentCyan)),
      );
    }
    if (landscapes.isEmpty) {
      return const _Message(
        icon: Icons.landscape_outlined,
        text: 'Todavía no hay paisajes disponibles.',
      );
    }
    return LandscapeGrid(
      landscapes: landscapes,
      onBuy: _buy,
      busyKey: _buying,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(icon, color: _secondaryTextColor, size: 40),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _secondaryTextColor, fontSize: 14),
          ),
          ?action,
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/coin_balance.dart';
import 'firmamento/tablas.dart';

/// El saldo de polvo estelar para las `actions` del AppBar, como en Cielos.
/// No se muestra mientras no se sepa.
class SaldoPolvo extends StatelessWidget {
  const SaldoPolvo({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: coinBalance,
      builder: (context, coins, _) => coins == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '$coins ✨',
                  semanticsLabel: '$coins de Polvo Estelar',
                  style: const TextStyle(color: kCian, fontWeight: FontWeight.bold),
                ),
              ),
            ),
    );
  }
}

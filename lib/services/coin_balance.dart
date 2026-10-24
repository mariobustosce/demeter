import 'package:flutter/foundation.dart';

/// Último saldo de polvo estelar que dio el servidor, o `null` si todavía no
/// se sabe. Lo actualizan el login, `/me` y el oráculo (`nuevo_balance`).
final ValueNotifier<int?> coinBalance = ValueNotifier<int?>(null);

/// Pone en [coinBalance] un saldo que llegó del servidor, si es un número.
void updateCoinBalance(Object? value) {
  final coins = value is num ? value.toInt() : int.tryParse('$value');
  if (coins != null) coinBalance.value = coins;
}

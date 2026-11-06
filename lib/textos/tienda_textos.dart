/// Textos de la Tienda: los de `lang/es/tienda.php` de la web, tal cual.
/// Las excepciones son propias de la app: el pago seguro (la web nombra a
/// Mercado Pago) y los estados de carga.
abstract final class TxTienda {
  static const cejilla = 'Tienda Estelar';
  static const tituloLinea1 = 'Tienda de';
  static const tituloLinea2 = 'Polvo Estelar';
  static const lema = 'Adquiere polvo estelar para consultar los astros.';
  static const mejorValor = 'MEJOR VALOR';
  static const polvoEstelar = 'polvo estelar';
  static const comprarAhora = 'Comprar ahora';
  static const procesando = 'Procesando...';

  static const saldo = 'Polvo estelar disponible';
  static const pagoSeguroPlay = 'Pago seguro con Google Play.';
  static const pagoSeguroAppStore = 'Pago seguro con la App Store.';
  static const sinPaquetes = 'Por ahora no hay paquetes a la venta. Vuelve a intentarlo más tarde.';
  static const reintentar = 'Reintentar';
  static const noSeVendeAqui =
      'El polvo estelar se compra desde la app de Android o iPhone. Aquí puedes usar el que ya tienes.';

  static const referidoTitulo = 'Gana Polvo Estelar';
  static const referidoAntes = 'Comparte tu código y gana ';
  static const referidoDespues = ' por cada amigo que se una y haga su primera consulta.';
  static const copiado = '¡CÓDIGO COPIADO!';
  static const tocaCopiar = 'Toca el código para copiarlo';
}

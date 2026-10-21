/// Constantes compartidas por toda la app.
///
/// Antes cada servicio y pantalla tenía sus propios valores por defecto de
/// coordenadas y sus propios timeouts, lo que producía cielos distintos según
/// desde dónde se pidiera el mapa. Todo eso vive acá ahora.
library;

/// Coordenadas por defecto: Santiago (La Florida), Chile — Hemisferio Sur.
///
/// Se usan cuando el GPS está apagado, sin permiso, o no alcanza a fijar
/// posición dentro de [kLocationTimeout].
const double kDefaultLatitude = -33.5227;
const double kDefaultLongitude = -70.5983;

/// Timeout de las llamadas al backend de astronomía (el render del SVG del
/// cielo es costoso en el servidor, por eso es generoso).
const Duration kApiTimeout = Duration(seconds: 45);

/// Timeout de las llamadas de autenticación. Corto a propósito: bloquean el
/// splash, así que preferimos caer al login antes que dejar la app colgada.
const Duration kAuthTimeout = Duration(seconds: 15);

/// Tiempo máximo que esperamos al GPS antes de usar las coordenadas por
/// defecto. Sin esto un GPS frío en interior puede colgar la carga inicial.
const Duration kLocationTimeout = Duration(seconds: 12);

/// Duración mínima del splash, para que el logo no parpadee.
const Duration kSplashMinDuration = Duration(seconds: 2);

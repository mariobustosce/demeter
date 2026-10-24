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

/// Base del API. Se cambia al compilar, sin tocar código:
/// `flutter run --dart-define=API_BASE=http://demeter.test/api`.
const String kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://windowsdemeter.com/api',
);

/// Raíz de las páginas web (el mapa del WebView): la base del API sin `/api`.
final String kWebBase = kApiBase.replaceFirst(RegExp(r'/api/?$'), '');

/// Rango de `?ratio=` (alto ÷ ancho del mapa) que acepta el servidor.
const double kMapRatioMin = 1.5;
const double kMapRatioMax = 2.4;

/// Cuándo sube la hoja que invita al invitado a entrar o crear la cuenta.
const Duration kGuestInviteDelay = Duration(seconds: 8);

/// Timeout por defecto de cualquier llamada al API.
const Duration kRequestTimeout = Duration(seconds: 20);

/// Timeout del oráculo. La respuesta la redacta un modelo de lenguaje y tarda;
/// cortar antes de tiempo puede dejar una consulta cobrada sin respuesta.
const Duration kOracleTimeout = Duration(seconds: 120);

/// Timeout de las llamadas al backend de astronomía (el render del SVG del
/// cielo es costoso en el servidor, por eso es generoso).
const Duration kApiTimeout = Duration(seconds: 45);

/// Timeout de las llamadas de autenticación. Corto a propósito: bloquean el
/// splash, así que preferimos caer al login antes que dejar la app colgada.
const Duration kAuthTimeout = Duration(seconds: 15);

/// Tiempo máximo que esperamos al GPS antes de usar las coordenadas por
/// defecto. Sin esto un GPS frío en interior puede colgar la carga inicial.
const Duration kLocationTimeout = Duration(seconds: 12);

/// Ruta de quien no tiene sesión (el mapa de invitado): el splash, el logout y
/// los 401 llevan aquí.
const String kGuestRoute = '/invitado';

/// User-Agent para Nominatim: su política pide identificar la app y un
/// contacto.
const String kNominatimUserAgent =
    'WindowsDemeter-App/1.0 (+https://windowsdemeter.com)';

/// Duración mínima del splash, para que el logo no parpadee.
const Duration kSplashMinDuration = Duration(seconds: 2);

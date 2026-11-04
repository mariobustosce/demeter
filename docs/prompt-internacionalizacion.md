# Prompt — Internacionalización de la app Flutter (demeter)

> **Cómo usarlo.** Abre Claude Code en `c:\laragon\www\demeter`, pega este archivo completo y pídele que empiece por la **Fase S** (servidor) o la **Fase 0** (app). Una fase por sesión; revisa cada una antes de pasar a la siguiente.
>
> **Objetivo.** Que todos los textos de la app vivan en un diccionario editable (`lib/l10n/app_es.arb`), que la app quede preparada para el **inglés** (`app_en.arb`) y que el idioma elegido llegue también al servidor: respuestas de la API, mapa en WebView, fondo animado y notificaciones push.
>
> **Plan gemelo.** La web ya hizo su parte: `celestialWindows/docs/prompt-internacionalizacion.md` (plan) y `celestialWindows/docs/internacionalizacion-cierre.md` (estado). Si el contrato `docs/api-app-movil.md` dice otra cosa que este prompt, **manda el contrato**.

---

## Contexto (radiografía real, 2026-11-03)

### El servidor (windowsdemeter.com)

- **Diccionario.** Está en `lang/es/<modulo>.php`: `mapa`, `paisajes`, `favoritos`, `alertas`, `tienda`, `cartas`, `oraculo`, `observatorio`, `paginas`, `admin`…, y el español es el idioma base.
- **Inglés del servidor.** En `lang/en/` hoy solo están `auth`, `ajustes`, `nav`, `comun`, `blog`, `validation`, `passwords`, `pagination`, `actions`, `http-statuses` y `correos`. **Faltan todos los módulos de producto.** Mientras falten, cualquier texto que venga del servidor sale en español aunque la app pida inglés: no da error, cae al español. Traducirlos es trabajo de la web, no de este prompt.
- **Cómo elige el idioma el servidor.** Lo resuelve el middleware `EstablecerIdioma` con esta prioridad: `?lang=` → `users.locale` → sesión → `Accept-Language` → `es`. Los idiomas válidos son `config('app.locales') = ['es', 'en']`.
- **La API.** Los `message`, el catálogo de paisajes y los avisos (`titulo`, `texto`, etiquetas de preferencias) salen en el idioma del `Accept-Language`. Los avisos se redactan en cada petición, así que el mismo aviso cambia de idioma con la cabecera.
- **Push.** Va en el idioma de `users.locale`, y si la cuenta no lo tiene fijado, en español. No depende de la cabecera de ninguna petición.
- **Kiosk y Lively.** Las rutas `/app/mapa/...` y `/lively/m/{token}/{modo}` no tienen sesión: **solo vale `?lang=`**. El refresco de 5 minutos del mapa ya conserva `?lang=` (`welcome.blade.php`, alrededor de la línea 1484).
- **Huecos del servidor para la app** (los cierra la Fase S):
  - La API no permite fijar `users.locale`. Solo existe `POST /idioma` en la web, con sesión.
  - `GET /api/me` y `GET /api/profile` no devuelven `locale`.
  - `ProfileController` (referidos) devuelve `share_message` en español fijo y sin tildes («Usa mi codigo…»). El medidor de la web no lo detecta porque solo busca tildes, ñ, ¿ y ¡.
  - Fuera de alcance a propósito: las preguntas del Oráculo y de Deméter (`PreguntasOraculo` y `PreguntasDemeter`), que también son el prompt de la IA, y las respuestas de la IA, que se piden en español. Los nombres de signos, planetas y casas de `ZodiacTables`, `HouseTables` y `AstrologyPresenter` tampoco se traducen todavía, porque su caché no lleva el idioma; está pendiente de decisión en la web.

### La app

- **Estado.** Rama `feat/app-webview`, fases 0-7 de `docs/prompt-actualizacion.md` hechas (última `8707a32`). Son 59 archivos `.dart`, con **todo el texto en español incrustado**.
- **Piezas que faltan.** No hay `flutter_localizations` ni `intl` en `pubspec.yaml`, ni `l10n.yaml`, ni ARB. Tampoco hay `Accept-Language` en `lib/services/api_client.dart` (cabeceras en la línea 101) ni `lang` en las URLs del mapa (`lib/services/map_urls.dart`).
- **Dónde está el texto.** Hay unas 170 cadenas con tildes en 35 archivos, más las que no llevan tildes. Los archivos con más texto:

  | Archivo | Cadenas aprox. |
  |---|---|
  | `lib/screens/astral_charts_screen.dart` | 43 |
  | `lib/widgets/wallpaper_sheet.dart` | 34 |
  | `lib/screens/user_map_tab.dart` | 28 |
  | `lib/screens/create_astral_chart_screen.dart` | 27 |
  | `lib/screens/oracle_consultations_screen.dart` | 23 |
  | `lib/services/billing_service.dart`, `new_consultation_screen.dart`, `avisos_screen.dart` | 18 c/u |
  | `map_web_view.dart`, `compatibility_screen.dart`, `alerts_tab.dart`, `consultation_detail_screen.dart`, `landscapes_screen.dart`, `favorite_landscape_sheet.dart`, `api_client.dart` | 11-15 c/u |
  | Resto de pantallas (login, registro, 2FA, perfil, tienda, splash, invitado, menú de modos…) | menos |

- **Android nativo.**
  - `android/app/src/main/res/values/strings.xml` tiene `wallpaper_description`, que usa `res/xml/celestial_wallpaper.xml` y no tiene versión `values-en`.
  - `CelestialWallpaperService.kt` arma por su cuenta la URL de `/lively/m/...` (alrededor de la línea 313) **sin `lang`**.
  - `android:label="WindowsDemeter"` es marca: no se traduce.
- **iOS.** No declara idiomas (`CFBundleLocalizations` en `ios/Runner/Info.plist`).

## Decisiones (no rediscutir)

1. **El diccionario es ARB con `gen-l10n`** (`flutter_localizations` + `intl`). La plantilla es `app_es.arb`, el español es la base y el fallback. Si falta una clave en inglés, se ve en español, nunca la clave pelada.
2. **Las claves son estructuradas y no el texto.** Formato camelCase con prefijo por pantalla o módulo, en español, como en la web: `cartasCrearTitulo`, `oraculoEnviar`, `tiendaComprarPolvo`, `comunCancelar`. Los parámetros siguen ICU (`{nombre}`) y los plurales usan `{n, plural, ...}`. Cada clave lleva `@descripcion` solo si el contexto no es obvio.
3. **Extracción 1:1.** El texto se mueve al ARB **sin reescribirlo ni «mejorarlo»**. Cambiar un texto es trabajo del usuario, después, en el ARB.
4. **Idioma de la app.** Por defecto, el del sistema si es `es` o `en`; si no, `es`. El usuario puede fijarlo en Perfil, y la elección se guarda en el dispositivo y, con sesión, en la cuenta (`users.locale`, que decide el idioma del push).
5. **Un solo idioma en toda la app.** El idioma de la app viaja al servidor siempre: `Accept-Language` en la API y `?lang=` en el WebView del mapa y en el fondo animado.
6. **La traducción al inglés la propone Claude y la revisa el usuario.** Se usa el glosario de marca ya aprobado de la web: `c:\laragon\www\celestialWindows\docs\glosario-ingles.md` (polvo estelar, Cielos/Firmamentos, modos, paisajes…). Nada se publica en inglés sin revisión.
7. **Lo que no se traduce.** El nombre «WindowsDemeter», los slugs, las claves técnicas (`basico`/`profesional`/`astronomico`, la clave de un paisaje), los logs y los mensajes de depuración.

## Decisiones pendientes (preguntar cuando toque, no implementar antes)

- **Al entrar con una cuenta que ya tiene `locale`**, distinto del que eligió el dispositivo: ¿manda la cuenta o el dispositivo? (Propuesta: si el usuario nunca eligió en este dispositivo, manda la cuenta; si eligió, se sube su elección.)
- **Textos de la tienda de Google Play** (ficha, nombres de productos `polvo_50/100/1000`): se configuran en la consola de Play, no en el código. Preguntar si entran en este trabajo.

## Reglas de trabajo

- Responde y comenta **en español**, con comentarios breves en el código nuevo.
- **Nunca hagas `git commit` ni `push` sin preguntar, cada vez.** El árbol tiene archivos sin seguimiento de otras sesiones en `docs/`: no los mezcles.
- **Qué va al ARB:** solo texto que ve el usuario: `Text`, `title`/`label`/`hint`/`tooltip`, `SnackBar`, diálogos, `Semantics`, textos de notificaciones locales y mensajes de error que la app redacta.
- **Qué no va al ARB:** los `message` que manda el servidor, que ya vienen traducidos. Se muestran tal cual y solo se pone en el ARB el texto de reserva de la app («Sin conexión», «Error inesperado»…).
- **Fechas y números** con `intl` y el locale activo (`DateFormat.yMMMd(locale)`, `NumberFormat`). Nunca formatos armados a mano con nombres de mes en español.
- Cada fase termina con `flutter analyze` en 0, `flutter test` verde, el medidor a la baja (Fase 0) y una prueba en el emulador en los dos idiomas.
- No toques el contrato de la API desde la app: si falta algo del servidor, se anota para la Fase S.
- Si una decisión de negocio no está aquí, **pregunta** antes de implementarla.

---

## Fase S — En el servidor (ejecutar en `celestialWindows`, antes de la Fase 1)

1. **`locale` en la cuenta por API.** `PUT /api/profile` acepta `locale` (opcional, `in:config('app.locales')`) y lo guarda en `users.locale`, la misma columna que escribe `IdiomaController`. `GET /api/me` y `GET /api/profile` devuelven `locale`, que es `null` si nunca eligió.
2. **`share_message`** de referidos al diccionario (`lang/es/ajustes.php` o el módulo que corresponda, con `:codigo`). Repasar los controladores de `app/Http/Controllers/Api/` buscando textos para el usuario **sin tildes**, que el medidor no ve, y moverlos también.
3. **Tests.** El locale se guarda y se devuelve, un locale inválido da 422, y `share_message` cambia con `Accept-Language: en`, aunque mientras no exista `lang/en/ajustes.php` caiga al español.
4. **Contrato.** Actualizar `docs/api-app-movil.md` (sección «Idioma» y perfil) y copiarlo a `demeter/docs/api-app-movil.md`.

## Fase 0 — Cimientos y medidor

1. Añadir `flutter_localizations` (sdk) e `intl` a `pubspec.yaml`, `generate: true` y `l10n.yaml`: `arb-dir: lib/l10n`, `template-arb-file: app_es.arb` y `output-localization-file: app_localizations.dart`. Usar la salida que genera el flutter del repo, sin `synthetic-package` si ya no se admite.
2. Crear `app_es.arb` y `app_en.arb` mínimos. En `MaterialApp`, poner `localizationsDelegates`, `supportedLocales` (`es`, `en`) y un `localeResolutionCallback` que caiga a `es`. El `title` sigue siendo «WindowsDemeter».
3. **`LocaleController`**, un `ChangeNotifier` o lo que use ya el repo:
   - Resuelve el idioma en este orden: elección guardada → sistema → `es`.
   - Guarda la elección en el almacenamiento del dispositivo.
   - Expone el código actual (`es`/`en`) a los servicios.
   - El `MaterialApp` se reconstruye al cambiar el idioma.
4. **Medidor** `tool/l10n_pendientes.dart`. Cuenta literales de texto visibles en `lib/` fuera de `lib/l10n/` y de los ARB, por archivo:
   - Cuenta literales dentro de `Text(`, `title:`, `label:`, `hintText:`, `tooltip:`, `content: Text`, `SnackBar` y cualquier cadena con tildes, ñ, ¿ o ¡.
   - Excluye comentarios, `debugPrint`, `log(` y claves técnicas.
   - Saca la cifra inicial en el resumen de la fase.
5. Un test de widget que monte la app con `Locale('en')` y con `Locale('es')` y compruebe que el delegado carga.

## Fase 1 — El idioma viaja al servidor

1. **`ApiClient`** manda `Accept-Language: <código>` en cada petición (cabeceras en `api_client.dart:101`), leído del `LocaleController`.
2. **Mapa en WebView.** `map_urls.dart` añade `lang=<código>` a las URLs de `/app/mapa/...`. Comprobar en el emulador que el refresco de 5 minutos y el cambio de favorito lo conservan. Al cambiar el idioma, el WebView recarga.
3. **Fondo animado.** `CelestialWallpaperService.kt` añade `appendQueryParameter("lang", …)`. El idioma le llega por el mismo canal por el que hoy recibe el enlace (preferencias compartidas o MethodChannel; mirar cómo está hecho y no inventar otro). Al cambiar el idioma, el fondo activo recarga.
4. **Cuenta.** Con sesión, al elegir idioma en la app se manda `PUT /api/profile {locale}`. Al entrar, aplicar la regla de la decisión pendiente (preguntar antes).
5. **Push.** Comprobar que el texto llega en el idioma de la cuenta, con `alertas:push-prueba {id}` en el servidor. Si la app arma alguna notificación local con texto propio, va al ARB.
6. **Tests.** La cabecera sale con el locale, la URL del mapa lleva `lang` y un cambio de idioma provoca la recarga.

## Fase 2 — Extracción de textos (1:1)

1. Recorrer las pantallas por el orden de la tabla del contexto, empezando por las más grandes, y luego el resto de `lib/`. Mover cada texto a `app_es.arb` con su clave y sustituirlo por `AppLocalizations.of(context)!.clave`, o con un atajo `context.l10n` si se añade una extensión.
2. **Textos fuera de un `BuildContext`** (servicios como `billing_service.dart` o `api_client.dart`):
   - Lo preferible es que el servicio devuelva un código o enum y que la pantalla lo traduzca.
   - Si no se puede, el servicio recibe un `AppLocalizations`. Nunca se instancia un idioma fijo.
3. Plurales, como «N planetas» o «N ✨», con `{n, plural, =1{…} other{…}}`, y fechas con `intl` en el locale activo.
4. Al acabar cada pantalla, el medidor de ese archivo queda en 0 o solo con lo técnico, que se justifica en el resumen.
5. `app_en.arb` todavía no se rellena: sin traducción, el fallback muestra el español.

## Fase 3 — Selector, nativo y plataformas

1. **Selector de idioma en Perfil** (Español / English), que aplica al momento lo de la Fase 1. También está disponible para el invitado si la app tiene ajustes sin sesión; si no, sigue al sistema.
2. **Android.** Crear `res/values-en/strings.xml` con `wallpaper_description` y cualquier otra cadena nativa visible, como textos de ajustes del fondo o del canal de notificaciones. Añadir `locales_config.xml` para el idioma por app de Android 13+, si encaja con el selector propio (preguntar si hay conflicto).
3. **iOS.** Declarar `CFBundleLocalizations` (`es`, `en`) en `Info.plist`.
4. **Pruebas.** Revisar a mano que no se corta ningún texto en inglés, que suele ser más largo o más corto, en botones, chips y hojas inferiores.

## Fase 4 — Traducción al inglés

1. Claude rellena `app_en.arb` completo aplicando `glosario-ingles.md`, sin cambiar los parámetros ni la estructura ICU.
2. Entregar una tabla de revisión con clave, español e inglés para los textos dudosos o de marca. **El usuario revisa** antes de dar la fase por hecha.
3. Test: ninguna clave de `app_es.arb` falta en `app_en.arb`, comprobado con un script o test que compare los dos ARB.

## Fase 5 — Verificación y cierre

1. `flutter analyze` en 0, `flutter test` verde y el medidor en 0, o con lo justificado.
2. Recorrido en el emulador en `en` y en `es`: invitado, login, 2FA, mapa (los tres modos), favoritos, paisajes, fondo animado, alertas y avisos, cartas, oráculo, tienda y perfil.
3. Anotar qué sigue en español **por el servidor** (módulos de `lang/en` sin traducir, presentadores astrológicos, preguntas del Oráculo y respuestas de la IA). No es un fallo de la app: se resuelve en `celestialWindows`.
4. Escribir `docs/cierre-internacionalizacion.md` con las cifras del medidor, lo excluido a propósito y lo pendiente del servidor.

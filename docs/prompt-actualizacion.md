# Prompt: actualizar la app Flutter (demeter) a lo que hoy tiene windowsdemeter.com

> **Cómo usarlo.** Abre Claude Code en `c:\laragon\www\demeter`, pega este archivo completo y pídele que empiece por la **Fase 0**. Haz una fase por sesión y revisa cada una antes de pasar a la siguiente.
>
> **Prompt gemelo.** Este prompt tiene un gemelo para el servidor: `celestialWindows/docs/prompt-app-movil.md`. Cuando el servidor termine, deja el contrato real en `celestialWindows/docs/api-app-movil.md`. Si ese contrato difiere de lo que dice aquí, **manda ese archivo**.

---

## Contexto

### La web

windowsdemeter.com (Laravel) ya tiene:
- Una portada con el **mapa animado sin sesión**: canvas con aves, clima, mar vivo y estrellas fugaces, con un paisaje al azar.
- Paisajes por favorito: 3 gratis y 6 premium a 100 ✨ de polvo estelar.
- Fondos Lively por token.
- Alertas de tres tipos: clima (Open-Meteo), catástrofes (GDACS) y avisos astrológicos (motor propio).
- Cobro en polvo estelar.

### La app

Esta app Flutter se quedó atrás en varias cosas:
- **Arranque.** Empieza en el login (`lib/screens/splash_screen.dart:26-45`).
- **Mapa.** Dibuja un SVG estático con `flutter_svg` (`/api/astronomy/map-svg-mobile`, en `lib/screens/home_screen_v2.dart:1711-1762`), sin animación ni paisajes.
- **Alertas.** No tiene alertas ni push.
- **Wallpaper.** El fondo de pantalla rasteriza ese mismo SVG.
- **Pagos.** Vende polvo estelar abriendo Mercado Pago en el navegador (`lib/screens/store_screen.dart:93-181`). La política de pagos de Google Play no lo permite para monedas virtuales.

### Decisiones del usuario

Ya están tomadas: no vuelvas a discutirlas.

1. **Mapa en WebView.** La app deja de dibujar el mapa y carga una página kiosk del servidor que muestra el mapa del teléfono con toda su animación, igual que Lively.
2. **Invitado.** Al abrir la app **sin sesión** se ve ese mapa, como en la portada web, y la app invita a «Entrar al portal» (login o registro). Con sesión, se ve el mapa del usuario con sus favoritos y paisajes.
3. **Alertas y notificaciones push** en la app.
4. **Fondo de pantalla Android: solo animado, tipo Lively.** Es un live wallpaper nativo que carga en un WebView el enlace del favorito. **Se elimina** el fondo estático y el live wallpaper actual hecho con FlutterEngine y SVG.
5. **Google Play Billing** para comprar polvo estelar, con el recibo verificado en el servidor. Mercado Pago desaparece de la app Android.
6. **Se descarta el renderizador nativo SkyView**: el trabajo sin commitear de `feat/cielo-canvas` (`lib/widgets/sky/`, `lib/models/sky/`, `lib/services/sky_data_service.dart`, sus tests y `assets/sky/`).
7. **Alcance.** Android completo. iOS debe **arrancar y funcionar** sin wallpaper; hoy se cae al abrir.
8. **Funciones que se conservan.** Cartas astrales, consultas al oráculo y polvo estelar ya funcionan: se conservan y solo se endurecen.

## Reglas de trabajo

- **Idioma.** Responde y comenta **en español**, con comentarios breves.
- **Git.** **Nunca hagas `git commit` ni `push` sin preguntar**, cada vez. Tampoco reescribas el historial ni hagas force-push sin una confirmación explícita.
- **Secretos.** **Ningún secreto en el código ni en los logs**: tokens, contraseñas, client secrets ni IDs de producción inventados. Si hace falta un ID real (AdMob, productos de Play o Firebase iOS), **pídeselo al usuario**. Si encuentras un secreto, indica el archivo y la línea, nunca el valor.
- **Datos personales.** No van en logs, URLs ni capturas. Las coordenadas del usuario se redondean a 2 decimales (unos 1 km) cuando viajan en una URL pública. Las de un favorito no viajan nunca: el servidor las saca del token.
- **Arquitectura.** La app no usa ninguna librería de estado (StatefulWidget, setState y servicios creados a mano). No metas Riverpod ni Bloc sin preguntar. Sí introduce un `ApiClient` único (fase 1).
- **Verificación.** Cada fase termina con `flutter analyze` sin errores nuevos, con tests de lo que se pueda testear y con una prueba en un dispositivo Android real de gama media.

---

## Fase 0: limpieza y urgencias

### 0.1 Credencial real publicada

`test_login.dart:8` tiene un email y una contraseña reales en texto plano. Está versionado desde el commit `5343ef8` y **subido a GitHub** (`origin/main`).

**Qué hacer:**
1. Borrar el archivo.
2. Avisar al usuario de que debe **cambiar esa contraseña ya**.
3. Proponerle purgar el historial con `git filter-repo`. Eso exige force-push y que todos vuelvan a clonar: **solo se hace con su confirmación**.
4. No repetir el valor en ningún mensaje.

### 0.2 Trabajo sin commitear de `feat/cielo-canvas`

La rama apunta al mismo commit que `main`, y todo está sin commitear. Hay de todo mezclado:
- SkyView (se descarta).
- El cambio de paquete `com/example/demeter` → `com/windowsdemeter` (borrados ya en el stage).
- `google-services.json` y el manifest.
- `lib/config/` (`app_config.dart`, `ads_config.dart`).
- `live_wallpaper_service.dart`.
- La versión `1.0.6+10`.
- Cambios en servicios y pantallas.

**Qué hacer:**
1. Hacer un **inventario archivo por archivo** con dos columnas: «es SkyView → descartar» y «otra cosa → conservar».
2. **Enseñárselo al usuario antes de borrar nada.**
3. Con su visto bueno, descartar SkyView, commitear lo que se conserva (preguntando) y crear la rama de trabajo `feat/app-webview`.

### 0.3 Basura en la raíz

Hay que borrar varias cosas:
- **Scripts sueltos**: `check_*.dart`, `fetch*.dart`, `test*.dart`, `refactor*.dart`, `fix_*.dart`, `clean_build.dart` y `find_build.dart`.
- **Logs**: `*_logs*.txt`, `flutter_aab_log.txt`, `build_log.txt`, `analysis_out.txt` y `android/build_android_aab_log.txt`.
  - Los `last_logs*.txt` y `final_attempt_logs.txt` son `laravel.log` del backend, con trazas y consultas SQL.
  - Los logs de Gradle llevan rutas con el nombre del usuario de Windows.
- **Capturas** `flutter_0*.png`, cinco de ellas de 0 bytes.
- **`lib/screens/home_screen.dart`**: está muerto, nadie lo importa.
- **`android/async_wallpaper/`**: carpeta perdida.
- **`.analysis/`**.

**Qué hacer además:**
- Ampliar el `.gitignore` con `*.txt` de logs, `.env*`, capturas, `GoogleService-Info.plist` si así se decide, y la basura de `packages/`.
- `android/gradle.properties:4` versiona un `org.gradle.java.home` con una ruta local. Hay que moverlo al `~/.gradle/gradle.properties` del usuario.

### 0.4 Logs que filtran datos

`main.dart:19-21` anula `debugPrint` **solo en el isolate de `main()`**: el de `wallpaperMain()` (`main.dart:43-47`) sigue imprimiendo en release.

| Archivo y línea | Qué expone | Qué hacer |
|---|---|---|
| `auth_service.dart:182` | El body completo de `/login/google`, que incluye el token Sanctum | Quitarlo |
| `sky_service.dart:69-71` y `:126-128` | La URL con lat/lon exactos | Quitarlo |
| `oracle_service.dart:99-100` y `:158-159` | Bodies completos de respuestas | Quitarlo |
| `wallpaper_refresh_service.dart:55-58` | `developer.log` con coordenadas | Desaparece en la fase 5 |

---

## Fase 1: núcleo seguro

Esta fase no depende del servidor. Puede ir en paralelo con las fases 0 y 1 del servidor.

### 1. `ApiClient` único

Reemplaza los `_getHeaders()` duplicados (`auth_service.dart:28`, `astral_chart_service.dart:12`, `profile_service.dart:14`, `store_service.dart:15`, `oracle_service.dart`, `sky_service.dart:76-79`) y la URL repetida a mano en `oracle_service.dart:7`.

- **URL base.** Por `--dart-define=API_BASE`, con producción por defecto.
- **Timeouts.** Timeout en **todas** las llamadas.
- **Errores:**
  - **401**: borra la sesión y vuelve al **mapa de invitado** (no al login).
  - **403 `insufficient_coins`**: lleva a la tienda.
  - **422**: errores de campo.
  - **429**: espera y reintenta.
- **Logs.** Nunca registra bodies ni cabeceras.

### 2. Token en `flutter_secure_storage`

Hoy el token está en SharedPreferences en texto plano, con la clave `sanctum_token` (`auth_service.dart:16-25`).

- **Migración.** Al arrancar, lee la clave vieja, la mueve al almacén seguro y la borra.
- **Backup.** En el manifest, `android:allowBackup="false"`, o reglas de `dataExtractionRules`/`fullBackupContent` que excluyan las prefs. Hoy el backup se lleva el token y las coordenadas.

### 3. `device_name` único por instalación

Un UUID guardado en el almacén seguro, por ejemplo `android:<uuid>`. El servidor revocará los tokens anteriores que tengan ese nombre.

### 4. Logout completo

Hoy solo borra el token. Debe:
1. Llamar a `POST /logout`.
2. Llamar a `DELETE /api/dispositivos` (fase 4).
3. Borrar el token.
4. Llamar a `FirebaseAuth.signOut()` y `GoogleSignIn.signOut()`.
5. Borrar la caché y las cookies del WebView.
6. Borrar `last_sky_data` y las prefs del usuario.

### 5. Login con Google

Hoy manda el **access token** de Google (`auth_service.dart:169`). Tiene que mandar el **ID token de Firebase** (`user.getIdToken()`) como `id_token`, que es lo que pedirá el servidor.

### 6. Login con 2FA

Si `POST /api/login` responde `{two_factor: true, desafio}`, se abre una pantalla para el código, o para un código de recuperación, que llama a `POST /api/login/2fa`.

### 7. Correcciones menores

- **Nominatim.** En `create_astral_chart_screen.dart:48`, `q` se interpola sin codificar. Usa `Uri.https` con `queryParameters` y un User-Agent identificable, como pide la política de Nominatim.
- **Saldo.** En `new_consultation_screen.dart:173` hay un TODO: el saldo debe actualizarse con `nuevo_balance`.
- **Zona horaria de la carta.** `create_astral_chart_screen.dart:41` usa `'UTC'` por defecto. Es un bug: **pregunta** si se calcula desde lat/lon o si lo resuelve el servidor.

### 8. Android

- **Permisos.** Declara `INTERNET` en el manifest principal; hoy solo llega por la fusión de los plugins.
- **Red.** Un `network_security_config` con `cleartextTrafficPermitted="false"`, y `demeter.test` permitido solo en `debug/`.
- **Firma.** `build.gradle.kts:29-33` lanza un error si falta `key.properties`, incluso en debug. Hay que firmar release solo cuando exista.
- **Recursos.** `isShrinkResources = true` en release, y reglas de R8 para los plugins nuevos.
- **AdMob.** Hoy hay IDs **de prueba** en el manifest (`:13-15`), en `Info.plist:5-7` y en `compatibility_screen.dart:71`, que no pasa por `AdsConfig`. Centralízalos en `AdsConfig` y **pide los IDs reales al usuario**.

### 9. iOS: que arranque

- **Firebase.** `lib/firebase_options.dart:14-21` lanza un error fuera de Android y `main.dart:24` lo espera, así que la app se cae. Se resuelve con `flutterfire configure`, que lo corre el usuario con su cuenta de Firebase.
- **Info.plist.** Añade `NSLocationWhenInUseUsageDescription`, el URL scheme y el `GIDClientID` de Google Sign-In, y el App ID de AdMob para iOS.
- **Funciones solo Android.** Oculta en iOS todo lo de wallpaper y `wallpaperMain`.
- **Compras en iOS.** Apple también exige su sistema de pago para bienes digitales, y la verificación del servidor solo será de Google. Mientras tanto, en iOS se ve el saldo y se gasta, pero **no se vende nada**. Déjalo anotado como decisión pendiente antes de publicar en la App Store.

---

## Fase 2: mapa en WebView y modo invitado

Depende de la fase 2 del servidor.

### Páginas que da el servidor

Las tres son kiosk: sin header, anuncios ni CSRF. Refrescan solas cada 5 minutos.

| URL | Para quién |
|---|---|
| `GET /app/mapa/{modo}?lat&lon&ratio` | Invitado |
| `GET /app/mapa/t/{token}/{modo}?lat&lon&ratio` | Usuario en su ubicación actual |
| `GET /app/mapa/t/{token}/{modo}/f/{favorito}?ratio` | Usuario en un favorito |

- **`modo`** vale `basico`, `profesional` o `astronomico`.
- **`ratio`** es alto/ancho del área del mapa, entre 1.5 y 2.4.
- **El token de vista** sale de `POST /api/app/vista` (Bearer). Vale unas 24 h: pide uno nuevo al abrir la app, al volver a primer plano si le queda menos de 1 h, o ante un 404.
- **El refresco** de la página borra la query salvo `lat`, `lon`, `ratio` y `paisaje`. Por eso todo lo demás va en el path.

### Requisitos

1. **Paquete.** Usa `webview_flutter`, que ya viene como dependencia transitiva.
   - Verifica en un dispositivo real que, con la app en segundo plano, el WebView **deja de animar** (CPU ≈ 0). Si no lo consigue, cambia a `flutter_inappwebview` y usa `pause()`/`pauseTimers()`. Deja la medición escrita.
2. **Seguridad del WebView:**
   - **Navegación.** El `NavigationDelegate` solo permite `https://windowsdemeter.com/app/mapa/...`. Cualquier otro enlace se abre fuera con `url_launcher` o se bloquea.
   - **Token.** **Nunca** se inyecta el Bearer en el WebView (ni cabeceras, ni cookies, ni JS).
   - **Puentes JS.** Ninguno con datos sensibles.
   - **Archivos y contenido mixto.** Sin acceso a archivos y sin contenido mixto.
   - **Logs.** Las URLs con token no se registran.
3. **Experiencia:**
   - **Pantalla.** El mapa va a pantalla completa con `SafeArea` nativo y fondo del color del cielo mientras carga.
   - **Errores.** Si la carga falla o no hay red, se muestra una pantalla nativa de reintento.
   - **Movimiento.** Con «quitar animaciones» de Android, el mar vivo no se anima. Es intencional, porque el servidor respeta `prefers-reduced-motion`.
4. **Ubicación del invitado:**
   - **Permiso.** Se pide con una explicación previa.
   - **Si lo niega**, se carga sin lat/lon y el servidor usa la IP o la ubicación por defecto.
   - **Redondeo.** Las coordenadas van redondeadas a 2 decimales.
5. **Flujo de pantallas:**
   - **Splash:**
     - **Sin sesión**: va a `GuestMapScreen`, con el WebView de invitado, un selector de modo nativo y un CTA «Entrar al portal» siempre visible. Pasados unos segundos sube además una hoja que invita a entrar o crear la cuenta.
     - **Con sesión**: va a `/home`.
   - **`/home` con sesión**: pestañas MAPA (WebView con token, chips nativos de favoritos y «Mi ubicación», modo), CONSULTAS, CARTAS y ALERTAS.
   - **401 en cualquier punto**: vuelve a `GuestMapScreen`.
6. **Qué se retira:**
   - El `SvgPicture` del mapa, el `InteractiveViewer`, el uso de `map-svg-mobile` y `celestial_screen_saver.dart`.
   - **Excepción: `map-api-mobile`.** Se queda mientras el oráculo lo use como contexto (`new_consultation_screen.dart:154`, que manda el JSON completo como `contexto_completo`). Coordínalo con la fase 1 del servidor, que limitará ese campo.

---

## Fase 3: favoritos y paisajes

Depende de la fase 3 del servidor.

### Favoritos

Las llamadas son:
- `GET /api/favoritos` para la lista.
- `POST /api/favoritos` con `{lat, lon, titulo?}`.
- `PATCH /api/favoritos/{id}` y `DELETE /api/favoritos/{id}`.

Requisitos:
- Se guarda desde «Mi ubicación».
- El tope lo marca el servidor: muestra su mensaje 422.
- **Al entrar con favoritos**, el mapa abre en el **primer favorito**, como en la web.

### Paisajes

Las llamadas son:
- `GET /api/paisajes` para el catálogo: `clave`, `titulo`, `descripcion`, `es_premium`, `precio_polvo`, `puede_usar` y `miniatura_url`.
- `GET` y `PATCH /api/favoritos/{id}/paisaje` para el paisaje de cada favorito.
- `POST /api/paisajes/{clave}/comprar`, que devuelve el saldo nuevo.

Requisitos:
- **Catálogo.** Cuadrícula de miniaturas con 🔒 y precio en los premium.
- **Nombre.** La sección se llama «Mis paisajes», como en la web.

---

## Fase 4: alertas y notificaciones push

Depende de la fase 3 del servidor.

### 1. Pantalla «Alertas»

- **Secciones.** Tres pestañas con los mismos nombres que la web: «Alertas climáticas», «Catástrofes en curso» y «Avisos astrológicos».
- **Preferencias.** Se leen y guardan con `GET/PUT /api/avisos/preferencias`.
- **Historial.** `GET /api/avisos`; se marcan como leídos con `POST /api/avisos/leidos` y `POST /api/avisos/{id}/leido`.
- **Sin favoritos.** Tener favoritos es requisito. Sin ellos se muestra un aviso que lleva a crear uno.
- **Aviso legal de GDACS.** En catástrofes se muestra siempre que la información es indicativa y no reemplaza a las autoridades locales.

### 2. Push con `firebase_messaging` y `flutter_local_notifications`

- **Permiso.** `POST_NOTIFICATIONS` (Android 13+) se pide **en contexto**, cuando el usuario activa su primera alerta, no al abrir la app.
- **Registro del dispositivo.** El token se registra con `POST /api/dispositivos` (`{fcm_token, plataforma, version_app}`). Se vuelve a registrar en `onTokenRefresh` y se borra al cerrar sesión.
- **Payload.** Trae `{aviso_id, tipo, titulo, texto}` y ninguna coordenada.
- **Comportamiento:**
  - **En primer plano**: notificación local.
  - **Al tocarla**: abre el aviso y lo marca como leído.
  - **Canal Android**: «Alertas», con visibilidad privada en la pantalla de bloqueo.
- **iOS.** El usuario debe subir la clave APNs a Firebase. Déjalo anotado.

---

## Fase 5: fondo de pantalla animado (Android)

Depende de la fase 3 del servidor.

### Lo que se elimina

- `wallpaper_refresh_service.dart` y la hoja de opciones del fondo estático (`home_screen_v2.dart:1390-1465`).
- El plugin `async_wallpaper` y `packages/async_wallpaper/`. Con ellos se van los permisos que mete:
  - `READ_MEDIA_*`, alarmas exactas, foreground service y `RECEIVE_BOOT_COMPLETED`;
  - el `VideoLiveWallpaper` duplicado del selector;
  - el `uses-feature live_wallpaper required=true`, que filtraba dispositivos en Play.
- `wallpaperMain`, `celestial_live_wallpaper.dart`, `live_wallpaper_service.dart` y el `FlutterEngine` de `CelestialWallpaperService.kt`.
- `SET_WALLPAPER`, si deja de hacer falta.

### Lo nuevo: `WallpaperService` nativo en Kotlin

1. **URL.** Carga `/lively/m/{token}/{modo}?ratio=…`, que sale de `GET /api/favoritos/{id}/fondo`. Su token es permanente y revocable, sin coordenadas.
2. **Cómo pintar el WebView sobre la superficie del wallpaper.** Haz primero una **prueba técnica** con dos opciones:
   - **(a)** Una `VirtualDisplay` sobre el `Surface` del wallpaper, con un `Presentation` que contiene el WebView. Así `requestAnimationFrame` corre de verdad y se compone por hardware.
   - **(b)** Un WebView sin ventana dibujado con `lockHardwareCanvas()` a cada cuadro.

   Ojo: un WebView sin ventana puede no animar. Mide las dos y elige con datos.
3. **Batería:**
   - **Oculto.** En `onVisibilityChanged(false)`, llama a `onPause()` y `pauseTimers()`; reanuda al volver a verse.
   - **Fotogramas.** Tope de fps configurable.
   - **Ahorro de energía.** Si `isPowerSaveMode` está activo, menos fps o pausa.
   - **Tamaño.** `onSurfaceChanged` recalcula `ratio`.
4. **Configuración desde la app:**
   1. Elige un favorito.
   2. Elige el modo: básico, profesional o astronómico, y rotativo si está desbloqueado.
   3. La app abre `WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER` con nuestro componente.

   Además se puede regenerar el enlace, lo que revoca el anterior.
   - **Paso de la URL.** La app se la pasa al servicio por `MethodChannel`, y el servicio la guarda en prefs privadas excluidas del backup.
5. **Sin red.** Se queda el último cuadro y se reintenta con backoff.
6. **Meta de rendimiento.** En un teléfono de gama media:
   - **Fluidez.** ≥25 fps con el peor clima.
   - **Sin degradación.** Se mide tras 15 minutos de uso, porque la web tuvo una degradación con el tiempo.
   - **Consumo.** Reporta el gasto de batería en 1 h, la memoria y los fps.

---

## Fase 6: Google Play Billing

Depende de la fase 4 del servidor.

1. **Paquete.** `in_app_purchase` (oficial).
2. **Productos.** Salen de `GET /api/store/packages?plataforma=android` (`google_play_product_id`). Los crea el usuario en Play Console.
3. **Compra:**
   1. Se compra con `applicationUserName`, que es el hash del id del usuario que exige el servidor.
   2. Con la compra en `purchaseStream`, la app llama a `POST /api/store/google-play/verificar` con `{product_id, purchase_token}`.
   3. Si el servidor responde OK, se actualiza el saldo y **solo entonces** se consume la compra (con `autoConsume` apagado).
4. **Casos especiales:**
   - **Compras pendientes.** Se manejan.
   - **Compras sin confirmar.** Al arrancar, las que no tienen confirmación del servidor se reverifican. El servidor es idempotente, así que no se acredita dos veces.
5. **Mercado Pago.** Se quitan de la app Android el botón «Comprar con Mercado Pago» y el polling de órdenes.

---

## Fase 7: verificación y publicación

1. **Calidad:**
   - `flutter analyze` limpio.
   - Tests unitarios:
     - del `ApiClient`: el 401 lleva al invitado, los timeouts y los errores;
     - de la migración del token;
     - de la renovación del token de vista.
   - Widget test del flujo de invitado a login.
2. **QA manual:**
   - **Android real.** Invitado con y sin permiso de ubicación; login con email, con Google y con 2FA; favoritos; compra de un paisaje; alerta push de prueba (desde el admin web «Gestión de alertas» → simular); fondo animado; compra en Play con una cuenta de prueba; logout.
   - **iOS.** Comprueba en el simulador que arranca.
3. **Play Console:**
   - Actualizar **Seguridad de los datos**: ubicación, token push, compras y cuenta.
   - Comprobar que ya no aparecen permisos sensibles.
   - Subir `versionCode`.
   - Verificar `targetSdk`.
4. **Cierre.** Resumen de lo que quedó pendiente y de las decisiones que siguen abiertas.

---

## Hallazgos de la auditoría que no están arriba

Para que no se pierdan:

- **Claves de Google en la app** (`google-services.json`, `firebase_options.dart`, `serverClientId` en `auth_service.dart:127`). No son secretos fuertes, pero el usuario debe **restringirlas** en Google Cloud por paquete y SHA-1. Hay dos clientes Android (`com.windowsdemeter` y `windowsdemeter.com`): confirma cuál sobra.
- **Bundle ID de iOS.** Es `windowsdemeter.com`, al revés que el de Android. Pregunta si se unifica antes de configurar Firebase iOS.
- **`key.properties` y `release.keystore`.** Están bien ignorados y nunca se versionaron. Recuerda al usuario que los respalde fuera del equipo, porque sin ellos no se puede actualizar la app en Play.
- **Ruido de los scripts.** Los de la raíz ensucian `flutter analyze`. Tras la fase 0, renueva la línea base.

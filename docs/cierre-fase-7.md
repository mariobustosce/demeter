# Cierre de la fase 7: verificación y publicación

Fecha: 2026-10-24. Rama `feat/app-webview`.

## Qué quedó verificado en esta fase

- **`flutter analyze`: 0 avisos** (venía con 115: deprecaciones de `withOpacity`, código muerto y contextos tras `await`).
- **Tests: 191 en verde** (incluye los de los arreglos de compras de la fase 6, commit `976f914`). Cobertura de lo que pedía la fase:
  - `ApiClient` (`test/api_client_test.dart`): 401 borra la sesión y avisa una sola vez, 401 sin token no toca nada, timeout, 403 `insufficient_coins`, 422, 429 con reintentos, errores sin exponer URL ni body.
  - Migración del token (`test/token_store_test.dart`): mueve la clave vieja de SharedPreferences al almacén seguro, no pisa un token más nuevo, reintenta si el almacén falla.
  - Renovación del token de vista (`test/map_view_service_test.dart` y `test/map_web_view_test.dart`): reutiliza con >1 h, renueva con <1 h y ante 404, llamadas simultáneas compartidas, se limpia en el logout.
  - Flujo invitado→login (`test/guest_to_login_flow_test.dart`, nuevo): splash sin sesión → mapa de invitado → «Entrar al portal» → `LoginScreen` real.
  - Decisión del splash (`test/splash_screen_test.dart`, nuevo): sin token → invitado sin llamar al API; token válido → `/home`; token rechazado → invitado con el token borrado.
  - Cableado global (`test/global_api_errors_test.dart`, nuevo): un 401 en cualquier llamada vacía la pila y deja solo el mapa de invitado; el 403 `insufficient_coins` abre la tienda.
- **Permisos fusionados sanos.** Del APK nuevo: `INTERNET`, ubicación (fine+coarse), `POST_NOTIFICATIONS`, más los de los SDK (`WAKE_LOCK`, `ACCESS_NETWORK_STATE`, `c2dm.RECEIVE`, `VIBRATE`, `AD_ID`/`ACCESS_ADSERVICES_*` de AdMob y `com.android.vending.BILLING` al recompilar). Ya no hay `READ_MEDIA_*`, alarmas exactas, foreground service ni `RECEIVE_BOOT_COMPLETED`; `live_wallpaper` y GPS quedaron declarados como opcionales.
- **Versión subida a `1.1.0+11`** (`versionCode` 11) en `pubspec.yaml`.

Arreglos que salieron de la verificación: el logo de Google del login ya no se descarga de internet (iba a gstatic en cada arranque y sin red quedaba roto), la fila de ese botón ya no desborda con letra grande, el buscador de `sky_service.dart` usa el User-Agent con contacto que exige Nominatim, `proguard-rules.pro` conserva Gson/`TypeToken` para `flutter_local_notifications` en release, y el perfil muestra el saldo vivo (`coinBalance`), con lo que una compra de Play acreditada con la tienda cerrada ya se refleja (el pendiente «I» de la fase 6).

## QA manual (pendiente, lo hace el usuario)

En un **Android real de gama media**, con un build nuevo (`flutter clean && flutter build apk --release` — ojo: el `app-release.apk` que hay en `build/` es anterior a las fases 5 y 6, no sirve):

- [ ] Invitado con y sin permiso de ubicación.
- [ ] Login con email, con Google y con 2FA.
- [ ] Favoritos (crear, renombrar, borrar; el mapa abre en el primero).
- [ ] Compra de un paisaje con polvo estelar.
- [ ] Alerta push de prueba (admin web «Gestión de alertas» → simular), con la app en primer plano y cerrada.
- [ ] Fondo animado: ponerlo, cambiar favorito/modo, regenerar el enlace, y las dos mediciones pendientes (`docs/medicion-fondo-animado.md` y `docs/medicion-webview-segundo-plano.md`).
- [ ] Compra en Play con una cuenta de prueba (probar también una compra pendiente), sobre el build **minificado**.
- [ ] Una push con el build minificado (verifica las reglas nuevas de R8).
- [ ] Logout completo.
- [ ] **iOS:** que arranca en el simulador (sin Firebase iOS pierde Google Sign-In y push, pero no debe caerse).

## Play Console (pendiente, lo hace el usuario)

1. **Seguridad de los datos.** Qué declarar, con la evidencia en el código:
   - **Ubicación aproximada**: recogida, opcional, no compartida, finalidad «funciones de la app». Todo lo que sale del teléfono va redondeado a 2 decimales (`location_service.dart`); **ubicación precisa: no**.
   - **Información personal**: nombre y email (cuenta), datos de nacimiento de las cartas (fecha, hora, lugar). No compartidos; el buscador de lugares consulta a Nominatim (OpenStreetMap) con el texto que escribe el usuario.
   - **Información financiera**: historial de compras (al servidor solo viajan `product_id` y `purchase_token`); los datos de pago los maneja Google Play, **no** se recogen.
   - **IDs de dispositivo**: token push FCM (se borra en el logout) y UUID por instalación (`device_name`). Además, **el ID de publicidad (AD_ID)** que recoge el SDK de AdMob: desde Android 13 Play lo exige declarado o rechaza la subida.
   - **Publicidad**: declarar lo del SDK de AdMob según la divulgación oficial de Google (AD_ID, IP, interacciones, diagnóstico; compartidos, finalidad publicidad).
   - **Contenido del usuario**: pregunta del oráculo, cartas y títulos de favoritos. Confirmar con el backend si la consulta al oráculo sale a un proveedor de IA externo (eso la volvería «compartida»).
   - **Cifrado en tránsito: sí** (cleartext prohibido en release). **Eliminación: sí** (logout + borrado de cuenta en la app); Play pide además una **URL web pública de eliminación de cuenta**: hay que publicarla en windowsdemeter.com y pegarla en la ficha.
2. **Permisos.** Confirmar en la consola que ya no aparecen los sensibles del viejo `async_wallpaper`.
3. **versionCode 11** ya puesto en `pubspec.yaml`; confirmar en la consola cuál es el último publicado antes de subir.
4. **targetSdk.** Viene de Flutter (`flutter.targetSdkVersion`); verificar en el build que cumple el mínimo vigente de Play (API 35).

## Pendientes que bloquean la publicación

- **IDs de AdMob reales.** Manifest Android, `Info.plist` de iOS y `lib/config/ads_config.dart` siguen con los de **prueba** de Google. Sin los reales no se publica.
- **Recompilar y verificar el manifest fusionado** (`build/app/intermediates/packaged_manifests/`): debe traer `versionCode 11`, `BILLING`, y nada del viejo wallpaper.
- **Respaldar `key.properties` y `release.keystore` fuera del equipo.** Nunca se versionaron (bien); sin ellos no se puede actualizar la app en Play.
- **Registrar la huella SHA-1 de release en Firebase.** El login con Google falla en el build de release (`PlatformException`) porque la huella del `release.keystore` no está registrada: Firebase → Configuración del proyecto → app `com.windowsdemeter` → «Agregar huella digital» → `E9:4D:03:F2:3A:76:67:7F:F5:3A:C6:FB:79:BD:09:28:3B:EC:A0:14`. No hace falta recompilar. De las huellas ya registradas, `72:48:9B:D1:…` es el debug de este equipo. **Ojo al publicar:** con la firma de apps de Play, Google refirma con su propia clave → añadir también la SHA-1 de «Firma de apps» (Play Console → Prueba y publica → Configuración → Firma de apps) o el login con Google fallará en la versión de Play.
- **Restringir las claves de Google** en Google Cloud por paquete + SHA-1, y confirmar en Firebase cuál de los **dos clientes Android** de `google-services.json` sobra (`com.windowsdemeter` vs `windowsdemeter.com`).

## Decisiones que siguen abiertas

- **Compras en iOS.** Apple exige su sistema de pago y el servidor solo verifica Google Play. Hoy en iOS se ve el saldo y se gasta, pero no se vende nada. Decidir antes de pensar en la App Store (StoreKit + verificación de recibos de Apple en el servidor).
- **Bundle ID de iOS.** Es `windowsdemeter.com`, al revés que Android (`com.windowsdemeter`). Decidir si se unifica **antes** de correr `flutterfire configure`, porque el registro en Firebase iOS usa ese bundle ID. Después: subir la clave APNs a Firebase y activar Push/Background Modes en Xcode.
- **Consentimiento de anuncios (UMP).** No hay flujo de consentimiento en la app; si se distribuye en el EEE/Reino Unido, Google lo exige antes de servir anuncios.
- **¿Solo ubicación aproximada?** La app pide `ACCESS_FINE_LOCATION` pero usa precisión media y redondea a 2 decimales. Con solo `COARSE` bastaría y la ficha de Play queda más limpia; probar en el QA antes de quitar FINE.
- **`map-api-mobile` como contexto del oráculo.** Sigue en uso; coordinar con el servidor cuándo se limita `contexto_completo`.
- **Dos botones muertos**: «detalles» de la carta astral (`astral_charts_screen.dart`) y «¿Olvidaste tu contraseña?» del login no hacen nada. Implementarlos o quitarlos antes de publicar.

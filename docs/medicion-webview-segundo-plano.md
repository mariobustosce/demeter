# Medición: el mapa en WebView deja de animar oculto

Requisito 1 de la fase 2: con la app en segundo plano, el WebView del mapa no
debe gastar CPU (≈ 0 %). Si no lo logra, se cambia `webview_flutter` por
`flutter_inappwebview` y se usan `pause()` y `pauseTimers()`.

**Estado: pendiente.** Hace falta un Android real de gama media; en la sesión
que implementó la fase 2 no había ninguno conectado.

## Qué hace hoy la app

- `webview_flutter` 4.13.1 con `webview_flutter_android` 4.11.0. Ninguno expone
  `onPause()`, `pauseTimers()` ni `destroy()` del WebView de Android.
- **App en segundo plano o pantalla apagada:** la app no hace nada especial.
  Depende de que Android WebView marque la página como oculta: entonces
  `requestAnimationFrame` se detiene, y la página no refresca el mapa porque
  escucha `visibilitychange`.
- **Otra pestaña (CONSULTAS, CARTAS, ALERTAS) u otra pantalla encima** (login,
  perfil, tienda): `MapWebView` saca el WebView del árbol y conserva el
  controlador. La página no se recarga al volver.

## Cómo medir

El mapa corre en **dos procesos**: el de la app (`com.windowsdemeter`) y el
renderer de WebView (`com.google.android.webview:sandboxed_process0`, o
`com.android.chrome:sandboxed_process0` en algunos teléfonos). Hay que sumar
los dos.

1. Instala un build **release** (el de debug gasta más):
   `flutter build apk --release` y luego `adb install -r build/app/outputs/flutter-apk/app-release.apk`.
2. Apunta el modelo, la versión de Android y la de *Android System WebView*
   (Ajustes → Apps).
3. Desactiva *Quitar animaciones* (Accesibilidad). Si está activa, el mar no
   se anima y la medición no sirve.
4. Abre el mapa, espera a que cargue y deja 1 minuto animando.
5. Mide **en primer plano**, 60 s con muestras cada 5 s:

   ```sh
   adb shell top -b -d 5 -n 12 -o PID,%CPU,RES,ARGS | grep -E "windowsdemeter|sandboxed_process"
   ```

   Si ese `top` no acepta `-o`, usa `adb shell top -b -d 5 -n 12` con el mismo
   `grep`.

6. Pulsa Inicio, espera 30 s y mide igual **en segundo plano**.
7. Repite el paso 6 en estos casos:
   - con la pantalla apagada;
   - con la app abierta en la pestaña CONSULTAS;
   - con el login abierto encima del mapa de invitado.
8. Haz todo dos veces: como invitado y con sesión.

**Criterio:** en cada caso oculto, el promedio de app + renderer es ≤ 1 % de
CPU, sin picos sostenidos.

## Resultados

Teléfono: … · Android … · WebView …

| Caso | Primer plano (% CPU) | Oculto (% CPU) | ¿Cumple? |
|---|---|---|---|
| Invitado, app en segundo plano | | | |
| Invitado, pantalla apagada | | | |
| Invitado, login encima | | | |
| Sesión, app en segundo plano | | | |
| Sesión, pantalla apagada | | | |
| Sesión, pestaña CONSULTAS | | | |

## Si algún caso no cumple

Cambiar a `flutter_inappwebview` (6.x):

- En `AppLifecycleState.paused` y `hidden`, llamar a `pause()` y a
  `pauseTimers()`. En `resumed`, llamar a `resume()` y a `resumeTimers()`.
  `pauseTimers()` es global: frena los timers de todos los WebView del proceso.
- Pasar a `InAppWebViewSettings` las reglas que hoy pone `MapWebView`: sin
  acceso a archivos ni contenido mixto, sin geolocalización, sin zoom y la
  consola sin copiarse al logcat.
- Mantener el `NavigationDelegate` equivalente (`shouldOverrideUrlLoading`)
  con `MapUrls.isMapPage` y `MapUrls.opensInBrowser`.

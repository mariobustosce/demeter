# Medición: el fondo animado (fase 5)

La fase 5 pide dos cosas que solo se miden en un Android real de gama media:

1. **La prueba técnica.** Hay dos formas de pintar el WebView en la superficie
   del fondo. Se miden las dos y se elige con datos.
2. **La meta de rendimiento:**
   - ≥ 25 fps con el peor clima;
   - sin degradación a los 15 minutos;
   - el gasto de batería en 1 h, la memoria y los fps.

**Estado: pendiente.** El usuario decidió probar en el teléfono después de la
fase 7. Mientras tanto la app usa **(a)**, que es lo que hace Flutter con sus
platform views. Cuando haya datos, se borra el pintor que pierda
(`Pintores.kt`) y este documento queda con los resultados.

## Las dos formas

| | Cómo | A favor | Riesgo |
|---|---|---|---|
| **(a) `pantalla`** | Una `VirtualDisplay` sobre la superficie del fondo, con un `Presentation` que contiene el WebView | El WebView está en una ventana: `requestAnimationFrame`, WAAPI y CSS corren y se componen por hardware | En Android 13 o menos no hay tope de fps: la pantalla virtual va al ritmo de la real |
| **(b) `lienzo`** | Un WebView sin ventana, dibujado con `lockHardwareCanvas()` a cada cuadro | El tope de fps es exacto: dibuja el servicio | Sin ventana, Chromium puede dar la página por oculta y no animar |

La página anima casi todo con WAAPI y CSS (nubes, lluvia, mar), no con un
bucle de `requestAnimationFrame`. Por eso el tope no se puede poner desde JS:
en (a) solo existe desde Android 14 (`setRequestedRefreshRate`).

## Qué hace el fondo

- **Proceso.** Corre en `com.windowsdemeter:fondo`, aparte de la app.
  `pauseTimers()` pausa todos los WebView del proceso: en el de la app pausaría
  también el mapa.
- **Oculto.** Hace `onPause()`, y `pauseTimers()` si no queda ningún Engine a
  la vista. En (a) además suelta la superficie y la pantalla virtual deja de
  componer.
- **Ahorro de energía.** Cada vez que el fondo se ve, la página anima 5 s y
  luego queda congelada. Lo hace como mucho cada 5 min, para que se ponga al
  día.
- **Sin red, 429 o 503.** Se queda el último cuadro y reintenta con backoff:
  10 s, 20 s, 40 s… hasta 30 min. Con el fondo oculto no reintenta.
- **404.** El enlace se regeneró en otro lado o se borró el favorito. En vez
  del mapa congelado, el fondo pide volver a elegir el lugar, y sigue
  reintentando.
- **Configuración.** La URL llega en `noBackupFilesDir/fondo_animado.json`,
  que escribe `MainActivity`. El servicio la vuelve a leer cada vez que el
  fondo se hace visible.

## Cómo medir

### 1. Compila cada variante

Las variantes se eligen al compilar. La app publicada no lleva estos
`--dart-define`:

```sh
flutter build apk --release --dart-define=FONDO_PINTOR=pantalla --dart-define=FONDO_MEDIR=true
flutter build apk --release --dart-define=FONDO_PINTOR=lienzo --dart-define=FONDO_MEDIR=true
```

- **Tope.** `--dart-define=FONDO_FPS=60` lo cambia; por defecto es 30.
- **Firma.** Sin `key.properties`, el release se firma con la clave de debug y
  sirve igual para medir.

### 2. Instala y pon el fondo

1. Instala con `adb install -r build/app/outputs/flutter-apk/app-release.apk`.
2. En la app, con sesión, toca 🖼 → elige un favorito → **Poner de fondo**.
3. **Al cambiar de variante,** pon antes otro fondo cualquiera y luego vuelve a
   poner el nuestro desde la app. El pintor queda fijo para cada Engine: un
   Engine nuevo es el único que toma el pintor nuevo.

### 3. Prepara el teléfono

- **Datos.** Apunta el modelo, la versión de Android y la de *Android System
  WebView*.
- **Animaciones.** Desactiva *Quitar animaciones* (Accesibilidad). Si está
  activa, el mar no se anima.
- **El peor clima** es la lluvia: la web llegó a caer a 7 fps con ella. El
  servidor no deja forzar el clima, así que usa un favorito donde esté lloviendo
  y el modo con más capas (profesional).
- **La app.** Ciérrala (deslízala fuera de recientes). Así el único renderer de
  WebView vivo es el del fondo.

### 4. Fluidez y degradación

```sh
adb logcat -s FondoFps
```

- Escribe una línea cada 10 s, con el fondo a la vista.
- Apunta los fps del **minuto 1** y del **minuto 15**.
- **En (b), mira también la pantalla.** El contador cuenta cuadros dibujados,
  no si cambian: tienen que moverse las nubes, el mar y las aves.

### 5. Memoria (minuto 1 y minuto 15)

```sh
adb shell dumpsys meminfo com.windowsdemeter:fondo | grep -E "TOTAL PSS|TOTAL:"
adb shell dumpsys meminfo | grep -i sandboxed_process
```

Suma el proceso `:fondo` y su renderer (`sandboxed_process`).

### 6. CPU: a la vista y oculto

```sh
adb shell top -b -d 5 -n 12 | grep -E "windowsdemeter:fondo|sandboxed_process"
```

Mídelo en cuatro casos:
- con el inicio a la vista;
- con la app abierta encima;
- con la pantalla apagada;
- con el ahorro de energía activo, pasados 5 s.

**Criterio:** oculto, ≤ 1 % de CPU.

### 7. Batería en 1 h

Con el cable conectado el teléfono no cuenta el gasto. Por eso se simula
desenchufado:

```sh
adb shell dumpsys battery unplug
adb shell svc power stayon true
adb shell dumpsys batterystats --reset
# 1 h con el inicio a la vista
adb shell dumpsys batterystats | grep -A40 "Estimated power use"
adb shell dumpsys battery reset
adb shell svc power stayon false
```

El uid de la app sale de `adb shell dumpsys package com.windowsdemeter | grep userId`.
Su renderer aislado cuenta para ese uid.

### 8. Sin red

1. Activa el modo avión y cambia el modo del fondo desde la app.
2. Al volver al inicio, el fondo debe quedarse con el cuadro anterior, sin la
   página de error de Chrome.
3. Quita el modo avión: el fondo debe cargar en el siguiente reintento (10 s,
   20 s, 40 s…).

## Resultados

Teléfono: … · Android … · WebView …

| Variante | fps min. 1 | fps min. 15 | Memoria min. 1 / 15 (MB) | CPU a la vista / oculto | Batería 1 h (mAh) | ¿Anima? |
|---|---|---|---|---|---|---|
| (a) pantalla, tope 30 | | | | | | |
| (b) lienzo, tope 30 | | | | | | |

**Elegida:** …

# Prompt — App Flutter (demeter): agregar un lugar a favoritos desde cualquier punto

> Cómo usarlo: abre Claude Code en `c:\laragon\www\demeter`, pega este archivo completo y pídele que empiece por la **Fase 1**. Una fase por sesión; revisa y prueba en un Android real antes de pasar a la siguiente.
> No hay trabajo de servidor: todo lo que usa este prompt ya está implementado y desplegado (contrato en `docs/api-app-movil.md`).

---

## Contexto

En la web, el panel «Controles del cielo» deja elegir **cualquier** lugar de tres formas: buscando una dirección, tocando un mapa o escribiendo latitud y longitud. Desde ahí se ve el cielo de ese punto y se guarda como favorito.

Cuando la app pasó al mapa en WebView (Fase 2 de `docs/prompt-actualizacion.md`), la Fase 3 solo pidió «se guarda desde Mi ubicación». Hoy `UserMapTab._saveCurrentPlace()` (`lib/screens/user_map_tab.dart`) es la **única** forma de crear un favorito: para guardar Valparaíso hay que estar en Valparaíso. Además, las pantallas que piden un favorito (`AlertsTab`, `wallpaper_sheet.dart` con `onCreateFavorite`) solo pueden mandar al mapa.

Este trabajo agrega esos controles a la app.

**Decisiones ya tomadas (no volver a discutirlas):**

1. Es **nativo**, no una página web: una hoja/pantalla «Agregar lugar» con las tres formas de la web (buscar, mapa, coordenadas).
2. El cielo del punto elegido se **previsualiza** en el WebView del mapa antes de guardarlo, igual que en la web, donde primero se actualiza el mapa y después se guarda.
3. El favorito se crea con el `POST /api/favoritos` de siempre. El tope (20) y sus mensajes los pone el servidor.
4. Los mosaicos del mapa son de **OpenStreetMap**. **No usar CARTO** (`basemaps.cartocdn.com`): desde 2026 pide API key y devuelve 200 con una imagen que dice «API KEY REQUIRED» en cada mosaico; la web se rompió así y no daba ningún error. Tampoco Google Maps (pide clave y facturación).
5. Fecha y hora del cielo (el otro control del panel web) **quedan fuera**: las páginas `/app/mapa/...` no aceptan momento en la URL. Si hace falta, es otro prompt con trabajo de servidor.

## Reglas de trabajo

- Responde y comenta **en español**. Comentarios de código breves.
- **Nunca hagas `git commit` ni `push` sin preguntar**, cada vez.
- **Datos personales**: la búsqueda, la dirección elegida y sus coordenadas no van a logs (`debugPrint` solo con el tipo de error, como ya hace `create_astral_chart_screen.dart`). En una URL del WebView, las coordenadas viajan con **2 decimales**; al servidor por `POST`, con **4**, como la web.
- Errores de negocio: `422 {success:false, message}` → muéstralo **tal cual**.
- Respeta el tema visual actual (`_sheetBackground`, las hojas de `user_map_tab.dart`); no inventes otro.
- Si una decisión de negocio no está aquí, **pregunta** antes de implementarla.

---

## Fase 1 — «Agregar lugar» con buscador y coordenadas (sin dependencias nuevas)

### 1. Un solo servicio de búsqueda

Hoy hay dos copias de la llamada a Nominatim: `SkyService.searchLocation` y `_searchLocations` en `create_astral_chart_screen.dart`. Únelas en `lib/services/geocoding_service.dart` y que las dos pantallas lo usen:

- `search(String texto)` → lista de `{nombre, nombreCorto, lat, lon}`, máximo 6. `nombreCorto` es «Ciudad, País», como el título que pone la web.
- Usa `kNominatimUserAgent` (`lib/config/app_config.dart`), `accept-language` del idioma de la app y `kRequestTimeout`.
- **Política de Nominatim**: como mucho 1 petición por segundo. Debounce de 400 ms, mínimo 3 caracteres, y cancela (ignora) la respuesta de una búsqueda vieja si ya hay otra en curso.
- Sin red o con error: lista vacía, sin excepción hacia la UI.

### 2. La hoja «Agregar lugar»

Ábrela desde:
- El selector de lugares de `UserMapTab` (`_PlaceMenu`): una fila **«＋ Agregar lugar»** al final, debajo de «Mi ubicación» y los favoritos.
- Los `onCreateFavorite` de `AlertsTab` y `wallpaper_sheet.dart`: hoy mandan al mapa. Que vayan al mapa **y** abran esta hoja.

Contenido, de arriba abajo:
1. Un conmutador **Buscar | Mapa** (la pestaña Mapa llega en la Fase 2; en esta fase déjala fuera o deshabilitada).
2. **Buscar**: campo de texto con sugerencias debajo. Al tocar una, se rellenan las coordenadas y el nombre.
3. **Coordenadas**: dos campos, latitud (−90 a 90) y longitud (−180 a 180), con teclado numérico con signo y validación en vivo (borde rojo fuera de rango, como `is-bad` en la web). Se pueden escribir a mano.
4. **Nombre** (opcional, máx. 60): se rellena con `nombreCorto` al elegir una sugerencia. Si queda vacío, no se manda `titulo` y el servidor pone el nombre del lugar o «Mi lugar N».
5. Botones:
   - **«Ver este cielo»**: cierra la hoja y carga el WebView con `MapUrls.user(..., location: <punto con 2 decimales>)`, es decir, `/app/mapa/t/{token}/{modo}?lat&lon`. El selector de lugares muestra entonces el nombre elegido (o «Lugar elegido») en vez de «Mi ubicación», con ★ para guardarlo. Si el punto está a menos de 50 m de un favorito, el servidor responde 302 a ese favorito: no hay que hacer nada especial.
   - **«★ Guardar en favoritos»**: `POST /api/favoritos` con `lat`/`lon` a 4 decimales y `titulo` si lo hay. Con 201 o 200 (`existente`), añade el favorito a la lista si no estaba, pasa a verlo (`/f/{id}`) y avisa «★ Guardado: …» o «★ Ya estaba en tus favoritos: …», como hoy.

### 3. Ajustes a lo que ya existe

- `FavoritesService.save` hoy recibe un `RoundedLocation` (2 decimales). Añade una variante, o un parámetro, para guardar un punto elegido con 4 decimales y `titulo` opcional, **sin** cambiar cómo se guarda «Mi ubicación».
- `_UserMapTabState` necesita distinguir tres estados de lo que se ve: favorito, «Mi ubicación» y **lugar elegido**. Hoy `_favoriteId == null` significa siempre «Mi ubicación»; no lo sigas usando así.
- La ★ junto al selector guarda lo que se ve: con un lugar elegido, guarda ese punto (4 decimales y su nombre), no la ubicación del teléfono.

### 4. Pruebas

- Unitarias del servicio de búsqueda con `http` falso: parseo, `nombreCorto`, error de red → lista vacía.
- De widget de la hoja con servicios falsos: validación de rangos, sugerencia → campos rellenos, guardar con 201, con 200 `existente` y con 422 del tope (se ve el `message`).
- `flutter analyze` en 0, como dejó la Fase 7.

---

## Fase 2 — Elegir en el mapa

### 1. Dependencias

`flutter_map` y `latlong2`, en la última versión estable compatible con el SDK del proyecto. Nada más.

### 2. La pestaña Mapa de la hoja

- `FlutterMap` de unos 260 px de alto, centrado en el punto de los campos de coordenadas o, si están vacíos, en lo que se ve en el mapa del cielo. Zoom inicial 5; 8 o más al elegir un punto (como `setView(..., max(zoom, 8))` en la web).
- `TileLayer`:
  - `urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'`.
  - `userAgentPackageName` con el id de la app: la política de uso de OSM bloquea a quien no se identifica.
  - Tono oscuro con un `ColorFiltered` de matriz que invierta y gire el tono 180°, equivalente a `filter: invert(1) hue-rotate(180deg) brightness(.85) contrast(.9)` de la web. Solo a los mosaicos, no al marcador.
- **Atribución obligatoria**: «© OpenStreetMap» visible (`RichAttributionWidget` o equivalente), con enlace a la licencia.
- Un marcador en el punto. **Tocar el mapa** mueve el marcador y rellena latitud y longitud (4 decimales). Después pide el nombre con reverse geocoding (`GeocodingService.reverse(lat, lon)` → `nombreCorto`, zoom 10, cacheado por coordenadas a 2 decimales como hace la web en `localStorage`) y, si llega, rellena el Nombre **solo si el usuario no lo escribió a mano**.
- Al cambiar las coordenadas a mano o con una sugerencia, el mapa se centra en el nuevo punto.
- Los gestos del mapa no deben arrastrar la hoja: usa una hoja a pantalla casi completa o desactiva el arrastre mientras se toca el mapa.

### 3. Pruebas

- De widget: tocar el mapa rellena los campos; el nombre escrito a mano no se pisa con el reverse.
- **Android real**: comprobar que los mosaicos cargan con imágenes reales (no grises ni con marca de agua), que la atribución se ve y que buscar, tocar, ver y guardar funcionan de punta a punta. Anota el resultado en `docs/cierre-fase-7.md`, en la lista de pruebas manuales.

---

## Contrato que se usa (ya implementado)

| Método y ruta | Uso |
|---|---|
| `POST /api/favoritos` | `{lat, lon, titulo? (máx. 60)}` → **201** nuevo o **200** si ya estaba (mismas coordenadas a 4 decimales): `{success, existente, favorito}`. Tope de 20: 422 con `message`. Límite 30/min. |
| `GET /app/mapa/t/{token}/{modo}?lat&lon&ratio` | Previsualizar un punto. A menos de ~50 m de un favorito: 302 a `/f/{id}`. |
| `GET /app/mapa/t/{token}/{modo}/f/{id}?ratio` | Ver el favorito recién guardado. |

Externos:
- Nominatim `search` y `reverse` (`nominatim.openstreetmap.org`), con `User-Agent` propio y ≤ 1 req/s.
- Mosaicos `tile.openstreetmap.org`, con `userAgentPackageName` y atribución.

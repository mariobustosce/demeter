# Prompt — App Flutter (demeter) para el Observatorio y los Estudios del cielo

> Cómo usarlo: abre Claude Code en `c:\laragon\www\demeter`, pega este archivo completo y pídele que empiece por la **Fase 1**. Ejecuta una fase por sesión, revisa y publica antes de pasar a la siguiente.
> Este prompt es el gemelo del trabajo ya hecho en el servidor (`celestialWindows`). El contrato de abajo está implementado, probado y desplegable: la app solo lo consume.

---

## Contexto

windowsdemeter.com renovó su pilar de cartas astrales. Ahora se llama **Observatorio** y tiene dos caras: **Cielos** (el clima actual de todos los lugares favoritos del usuario, en tarjetas) y **Firmamentos** (las cartas astrales de siempre, renombradas de cara al usuario: un firmamento es "la foto de los astros del cielo en un momento y lugar"). Sobre Cielos vive el producto nuevo: el **Estudio del cielo**, una suscripción anual por favorito (100 ✨ de polvo estelar) que captura clima + astronomía 4 veces al día en la hora local del lugar, con exportación CSV/JSON a 25 ✨ por descarga.

La app Flutter ya consume favoritos, paisajes, avisos, tienda y cartas por la API con Sanctum (ver `demeter/docs/prompt-actualizacion.md` y el contrato `docs/api-app-movil.md` del servidor). Este trabajo agrega la cara nativa del Observatorio.

**Decisiones ya tomadas por el usuario (no volver a discutirlas):**

1. El Observatorio en la app es **nativo por API** (no WebView): sigue el patrón de las pantallas de favoritos y paisajes.
2. Los nombres de cara al usuario son **Observatorio**, **Cielos**, **Firmamentos** y **Estudio del cielo**. "Carta astral" sobrevive solo como aclaración en la primera mención de una pantalla ("Firmamentos — tus cartas astrales").
3. El estudio y la exportación se pagan con **polvo estelar ya comprado** (como los paisajes premium): **no pasan por Google Play Billing**. Play Billing sigue solo para comprar polvo.
4. Los **precios nunca se escriben en la app**: siempre salen de `precios` en `GET /api/observatorio` (con el cobro apagado o para admins llegan en 0 y los botones no muestran precio).
5. Un estudio vencido queda **en pausa pero legible y exportable**; renovar (disponible desde 30 días antes de vencer) reanuda las capturas. Un estudio "huérfano" (favorito borrado) se lee y exporta pero no se renueva.

## Reglas de trabajo

- Responde y comenta **en español**. Comentarios de código breves.
- **Nunca hagas `git commit` ni `push` sin preguntar**, cada vez.
- **Ningún dato personal en URLs ni logs**: el contrato ya usa ids (nunca coordenadas en la URL); no lo "mejores" agregándolas.
- Errores de negocio: el servidor responde `422 {success: false, message}` con un mensaje ya escrito para el usuario — **muéstralo tal cual**, no lo traduzcas ni lo reemplaces. Un `404` en estudios ajenos es esperado: trátalo como "no existe".
- Respeta el tema visual actual de la app; no inventes otro.
- Si una decisión de negocio no está aquí, **pregunta** antes de implementarla.

## Fase 1 — Renombrado a Firmamentos

La pestaña/pantalla de "Cartas" pasa a llamarse **Firmamentos** (subtítulo o primera línea: "tus cartas astrales: fotos de los astros del cielo"). Renombra títulos, botones ("Nueva carta" → "Nuevo firmamento") y textos propios de la app. Los mensajes que vienen del servidor ya llegan renombrados (p. ej. "Firmamento generado exitosamente"): quita cualquier texto local que diga "carta astral" al mostrar esas respuestas. El contrato técnico (`/api/user/charts`, tipo `Carta`) **no cambia**.

## Fase 2 — Pantalla Cielos (el Observatorio)

1. Nueva entrada de navegación **Observatorio** que abre **Cielos**: una lista/grid de tarjetas, una por favorito, desde `GET /api/observatorio`.
2. Tarjeta: título del lugar, icono según `codigo_wmo` + `es_de_dia`, temperatura grande, viento, humedad, precipitación; si `reserva` es true, un distintivo "clima de reserva" (no es de ahora). `clima` puede venir `null`: muestra la tarjeta igual, con guiones.
3. Pie de tarjeta según `estudio`:
   - `null` → botón "Estudiar este cielo · {precios.estudio_anual} ✨/año" (sin precio si llega 0) → `POST /api/favoritos/{id}/estudio` con diálogo de confirmación.
   - `activo: true` → "Ver estudio" + "vence {expira}"; si `renovable`, también "Renovar".
   - `activo: false` → "Estudio en pausa · lo capturado queda" + "Renovar" (si `renovable`) + "Ver lo capturado".
4. Los `huerfanos` del payload van al final: tarjeta simple "El lugar ya no está en tus favoritos" con acceso al detalle.
5. Tras contratar o renovar, actualiza el saldo visible con el `saldo` de la respuesta.
6. Un switch o acceso visible lleva de Cielos a **Firmamentos** (la pantalla de la fase 1) y de vuelta: las dos caras del Observatorio.

## Fase 3 — Detalle del estudio

1. `GET /api/estudios/{id}` para la cabecera (título, estado, rango de fechas, total de capturas) y `GET /api/estudios/{id}/capturas?desde&hasta&por_pagina` para la serie (paginada, más reciente primero).
2. Gráfico simple de temperatura (campo `clima.t` de cada captura): los turnos con `clima: null` son huecos visibles, no se interpolan. Vale cualquier chart liviano ya presente en el proyecto; no agregues dependencias pesadas.
3. Tabla/lista de capturas: fecha local, turno (manana/dia/tarde/noche), icono WMO, temperatura, viento, humedad, lluvia, y el resumen astro (`astro.cuerpos.sun.alt`, `astro.cuerpos.moon.alt`, `astro.luna.ilum`).
4. Si el estudio está en pausa, un aviso arriba ("renueva para reanudar la captura") sin bloquear nada.
5. Leyenda de claves del JSON compacto (la trae también la exportación JSON): `t` °C, `h` humedad %, `n` nubosidad %, `vv` viento km/h, `vd` dirección °, `pp` mm, `pr` hPa, `wmo` código, `dia` 1=día, `uv` índice; por cuerpo: `lon` longitud eclíptica, `sg` índice de signo 0-11, `az` azimut, `alt` altura, `sh` 1=sobre el horizonte, `r` 1=retrógrado, `v` velocidad °/día.

## Fase 4 — Exportación

1. Botones "Descargar CSV" y "Descargar JSON" en el detalle: `POST /api/estudios/{id}/exportar/{formato}` con diálogo de confirmación que muestre `precios.descarga` (sin precio si llega 0).
2. La respuesta es el archivo (`Content-Disposition` attachment): guárdalo con el flujo de descargas de la plataforma y ofrece el share sheet.
3. Un `422` aquí es "te falta polvo": muestra el `message` y no descuentes nada localmente.
4. El cobro es **por descarga**: no caches el archivo para "regalar" descargas repetidas.

## Contrato (implementado y probado en el servidor)

Todas con `auth:sanctum` (Bearer). Los errores de negocio son `422 {success:false, message}`.

| Método y ruta | Uso en la app |
|---|---|
| `GET /api/observatorio` | `{success, saldo, precios: {estudio_anual, descarga}, lugares: [{favorito_id, titulo, lat, lon, clima: {temperatura, codigo_wmo, es_de_dia, viento_kmh, humedad_pct, precipitacion_mm, reserva} \| null, estudio: Estudio \| null}], huerfanos: [Estudio]}` |
| `POST /api/favoritos/{favorito}/estudio` | Contratar · `{success, saldo, estudio}` · throttle 10/min |
| `POST /api/estudios/{estudio}/renovar` | Renovar · `{success, saldo, estudio}` · throttle 10/min |
| `GET /api/estudios/{estudio}` | `{success, estudio: Estudio + {lat, lon, primera_captura, ultima_captura}}` |
| `GET /api/estudios/{estudio}/capturas?desde&hasta&por_pagina` | `{success, capturas: [{fecha_local, turno, capturado_utc, clima \| null, astro}], paginacion: {pagina, por_pagina, total, ultima_pagina}}` (máx. 200 por página) |
| `POST /api/estudios/{estudio}/exportar/{csv\|json}` | El archivo como descarga · cobra por descarga · throttle 6/min |

Tipo `Estudio`: `{id, titulo, activo, desde, expira, renovable, capturas}`.

Notas:
- `turno` ∈ `manana | dia | tarde | noche` (07, 13, 19 y 01 h en la hora local del lugar).
- `clima: null` en una captura = Open-Meteo estuvo caído toda la ventana; el astro siempre está (motor propio del servidor).
- Lo ajeno responde `404`, no `403`.

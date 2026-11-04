# Prompt — App Flutter (demeter): Firmamentos rediseñados y Observatorio

> **Cómo usarlo.** Abre Claude Code en `c:\laragon\www\demeter`, pega este archivo completo y pídele que empiece por la **Fase 1**. Ejecuta una fase por sesión, y revisa y prueba en un Android real antes de pasar a la siguiente.
>
> **Reemplaza a** `demeter/docs/prompt-app-observatorio.md`, que quedó desactualizado: no ejecutes ese.
>
> **Servidor ya hecho.** Todo lo que usa este prompt está implementado y probado en `celestialWindows` (noviembre de 2026). El contrato completo es `docs/api-app-movil.md` del servidor: copia la versión nueva a `demeter/docs/` antes de empezar. Si este prompt y el contrato discrepan, **manda el contrato**.

---

## Contexto

En noviembre de 2026 windowsdemeter.com cambió en dos frentes que la app todavía no refleja.

### 1. Firmamentos (cartas astrales), más fáciles de leer y más rigurosos

El motor del servidor se corrigió y la página de detalle se rediseñó:

- **Zona horaria.** Ahora es la zona IANA del lugar de nacimiento, con su historial de horarios de verano. Por ejemplo, Santiago el 07/04/2021 estaba en UTC−4, porque el horario de verano terminó el día 4. Antes se aceptaba «UTC» por defecto, y una hora local guardada como UTC corría el Ascendente y las casas varias horas.
- **Cuerpos.** Se suman **Plutón y Quirón**.
- **Orbes.** Cada aspecto tiene un orbe por tipo y por clase de cuerpo.
- **Figuras.** Hay figuras nuevas (pequeño gran trígono, cometa, rectángulo místico y tensiones angulares) y los stelliums se detectan bien.
- **Datos que lee un astrólogo:** dignidades, secta, fase lunar de Rudhyar, reparto ponderado, regentes de casas, planetas angulares, planeta más fuerte, lunación prenatal y eclipses prenatales. También indica si un cuerpo está retrógrado (R), estacionario (E) o fuera de límites (OOB).
- **Recálculo.** Las cartas calculadas con el motor anterior se recalculan solas en el servidor al pedir su detalle.

La app hoy:

- `lib/screens/create_astral_chart_screen.dart:40` parte con `_selectedTimezone = 'UTC'`. **Es el mismo error que se corrigió en la web.**
- No hay pantalla de detalle de un firmamento: solo el listado (`astral_charts_screen.dart`) y el alta.

### 2. Observatorio y Estudios del cielo

El pilar de cartas pasó a llamarse **Observatorio** y tiene dos caras:

- **Cielos:** el clima actual de cada favorito, en tarjetas.
- **Firmamentos:** las cartas astrales.

Sobre Cielos vive el **Estudio del cielo**, una suscripción anual por favorito que captura clima y astronomía 4 veces al día en la hora local del lugar, con exportación CSV o JSON pagada por descarga. Nada de esto existe aún en la app.

Desde el último prompt, el detalle del estudio en la web ganó:

- hora local y estación del año por captura;
- punto de rocío, sensación térmica, ráfagas y lluvia de las 6 h previas;
- un **resumen de 14 días** con KPI y el rango diario comparado con la **normal climatológica** del lugar.

## Decisiones ya tomadas (no rediscutir)

1. **Todo nativo por API**, sin WebView, con el patrón de las pantallas de favoritos y paisajes.
2. **Nombres de cara al usuario:** Observatorio, Cielos, Firmamentos y Estudio del cielo. «Carta astral» solo sobrevive como aclaración en la primera mención («Firmamentos — tus cartas astrales»). El contrato técnico (`/api/user/charts`, tipo `Carta`) no cambia de nombre.
3. **La zona horaria es la del lugar, nunca la del teléfono ni «UTC» por defecto.** Al elegir el lugar, la app pide `GET /api/user/zona` y muestra la zona y su desfase de ese día. Si el usuario no toca nada, el alta va **sin** `timezone` y el servidor la resuelve.
4. **El detalle de un firmamento se arma solo con `data.firmamento`.** `chart_data_json` es interno y puede cambiar de forma: no se lee.
5. **Los precios nunca se escriben en la app.** Salen de `precios` en `GET /api/observatorio`. En 0 (cobro apagado o admin), los botones no muestran precio.
6. **El estudio y la exportación se pagan con polvo estelar ya comprado**, sin Google Play Billing, que sigue solo para comprar polvo.
7. **Un estudio vencido queda en pausa**, pero se puede leer y exportar. Renovar está disponible desde 30 días antes de vencer. Uno huérfano (el favorito se borró) se lee y se exporta, pero no se renueva.
8. **Nada de librerías de gráficos nuevas.** La rueda natal, los gráficos del estudio y el aspectario se dibujan con `CustomPainter` y widgets propios. Hoy `pubspec.yaml` no tiene ninguna y debe seguir así.
9. **Coherencia visual total con la app actual:**
   - mismos fondos, tarjetas, bordes, radios y tipografía;
   - nada de colores, sombras, gradientes ni fuentes nuevas;
   - los colores de cuerpos, aspectos y figuras **vienen del servidor** (campo `color`), y los de elementos, signos y estados están en la tabla del final;
   - los encabezados de sección siguen el estilo de las pantallas actuales.

## Reglas de trabajo

- Responde y comenta **en español**, con comentarios de código breves.
- **Nunca hagas `git commit` ni `push` sin preguntar**, cada vez.
- **Ningún dato personal en URLs ni logs.** La fecha, hora y lugar de nacimiento son del usuario: no van a analytics, ni a logs, ni a ningún otro servicio. El contrato usa ids; no lo «mejores» agregando coordenadas a una URL. `GET /api/user/zona` lleva lat y lon por query porque las pide el propio usuario para su formulario; no lo registres.
- **Errores de negocio:** `422 {success: false, message}` trae un mensaje listo para el usuario. Muéstralo tal cual. Un `404` sobre algo ajeno es «no existe».
- **Idioma:** si `demeter/docs/prompt-internacionalizacion.md` ya se ejecutó (existe `lib/l10n/app_es.arb`), todo texto nuevo va al ARB. Si no, agrúpalo en constantes por pantalla para que la extracción sea 1:1. En ambos casos, los textos que llegan del servidor (nombres de cuerpos y figuras, `resumen`, `message`) se muestran tal cual.
- **Pruebas:** `flutter analyze` en 0 y `flutter test` en verde en cada fase. Los widgets que dibujan llevan al menos un test de pintura o de golden con los datos de ejemplo del final.
- Si una decisión de negocio no está aquí, **pregunta** antes de implementarla.

---

## Fase 1 — Firmamentos: nombre y zona correcta en el alta

Es urgente: hoy se siguen creando cartas con la zona equivocada.

1. **Renombrado.** La pantalla de cartas pasa a **Firmamentos**, con la primera línea «tus cartas astrales: fotos de los astros del cielo en un momento y lugar». Cambia «Nueva carta» por «Nuevo firmamento» y quita los textos locales que digan «carta astral» al mostrar respuestas del servidor (ya llegan renombradas).
2. **Zona del lugar en `create_astral_chart_screen.dart`:**
   - Quita el valor por defecto `'UTC'` y la lista fija de zonas como opción principal.
   - Cuando el usuario fija el lugar (y cada vez que cambian la fecha o la hora), llama a `GET /api/user/zona?lat&lon&fecha&hora` y muestra bajo el campo: «America/Santiago · ese día regía UTC−04:00» (más «horario de verano» si `horario_verano`).
   - Deja un «Cambiar zona» discreto para elegir otra IANA. Es el caso raro de una hora anotada en otra zona.
   - **Al guardar:**
     - si el usuario no cambió la zona sugerida, manda el alta **sin** `timezone`;
     - si la cambió, manda el nombre IANA elegido;
     - nunca mandes un desfase fijo.
   - Si `GET /api/user/zona` falla (red), no bloquees: guarda sin `timezone` y el servidor la resuelve.
3. **Listado.** Si `Carta.tz_revisar` es true, muestra un distintivo discreto «🕐 revisar zona» en la tarjeta del firmamento.
4. **Tests:**
   - el alta sin tocar la zona no manda `timezone`;
   - un cambio manual manda el nombre IANA;
   - el distintivo aparece con `tz_revisar`.

## Fase 2 — Detalle del firmamento

Pantalla nueva, que se abre al tocar una tarjeta del listado. Pide `GET /api/user/charts/{id}` y usa solo `data.firmamento`. El alta (`201`) ya devuelve `data.firmamento`: navega directo al detalle sin otra petición.

**Orden de secciones.** En móvil es una sola columna. En tablet va en dos columnas, con el par rueda y Dominantes arriba.

1. **Cabecera.**
   - Título.
   - Fecha y hora local, `zona.timezone (zona.rotulo)` y coordenadas.
   - Debajo, en una línea: **Big Three y regente**, por ejemplo «☉ Aries · ☽ Acuario · AC Tauro — Regente: ♀ Venus en Aries, casa XII, exilio». Sale de `natal.big_three` y `natal.chart_ruler`.
2. **Aviso de zona** (si `zona.revisar` y hay `zona.sugerida`): «Este firmamento se calculó con {timezone} ({rotulo}), pero en ese lugar y esa fecha regía {sugerida.timezone}, {sugerida.rotulo}. Si la hora se anotó en hora local, el Ascendente y las casas están corridos». Lleva un botón «Recalcular con {sugerida.timezone}», que se detalla en la Fase 3.
3. **Rueda natal** (ver la especificación abajo).
4. **Dominantes**, en una tarjeta:
   - Planetas angulares: `natal.angular`, por ejemplo «♄ Saturno sobre el MC · 0°44′».
   - Los 3 aspectos más cerrados: `natal.tight_aspects`.
   - Figuras: la `etiqueta` de cada una, más `detalle` si viene.
   - Elemento y modalidad dominantes: `natal.dominant`.
   - Planeta más fuerte: `natal.strongest`, con sus `reasons` y su número de aspectos.
5. **Posiciones.** Una fila por cuerpo de `cuerpos`:
   - glifo con su `color`;
   - nombre (en cursiva tenue si `es_punto`);
   - glifo del signo y grado (`grado_en_signo` como `17°55′`);
   - casa en romano;
   - **badge de dignidad** (Domicilio, Exaltación, Exilio o Caída, entre paréntesis y atenuado si `modern`);
   - badges **R**, **E** y **OOB**. R solo si `retrogrado`; los nodos ya llegan en false.

   Una nota pequeña al pie explica R, E y OOB. **No** hay columnas de constelación, altura ni °/día: eso no se muestra en la app.
6. **Aspectos**, con un conmutador **Lista / Grilla** con el estilo de los chips de la app:
   - **Chips de filtro** por tipo (`nombre`, `simbolo` y `color`, con su número). Tocar uno lo apaga y lo enciende.
   - **Lista**, en tres grupos por `grupo`: «Mayores», «A los ángulos» y «Menores» (este último plegado por defecto). Cada fila lleva los glifos del par y el del aspecto en su color, los nombres, `orbe_dm` y una «a» (aplicativo) o «s» (separativo) tenue. Los aspectos con `orbe` menor a 1 llevan un borde de acento.
   - **Grilla** (aspectario triangular):
     - filas y columnas en el orden de `cuerpos` más `asc` y `mc`;
     - cada celda lleva el glifo del aspecto en su color, el `orbe_dm` y la a o la s;
     - las celdas con `orbe` menor a 1 llevan el borde de acento;
     - se desplaza en horizontal en móvil.
   - Tocar un aspecto (en la lista o en la grilla) lo resalta en la rueda.
7. **Figuras.** Una tarjeta por figura con su `color`:
   - `etiqueta` y glifos de `cuerpos`;
   - `detalle` (o los nombres de los cuerpos);
   - «asociados por conjunción: …» si hay `asociados`.
8. **Ejes y casas:**
   - Los cuatro ejes con signo y grado.
   - Las 12 cúspides, cada una con el regente tradicional y la casa donde está, más el moderno entre paréntesis si lo hay (`natal.house_rulers`). Por ejemplo: «X ♒ 11°08′ · regente ♄ en X».
   - Al pie, `sistema_casas`.
9. **Reparto:**
   - Barras de elementos y de modalidades **ponderadas** (`reparto.*.weight`), con el conteo simple `count` en gris al lado.
   - **Secta:** «Carta diurna» o «Carta nocturna», con su luminar.
   - **Hemisferios por casa** (`natal.hemispheres`): sobre y bajo el horizonte, este y oeste.
   - Una nota: «Por casa, con los mismos 10 planetas».
10. **Sol y Luna:**
    - Signo, grado, casa y dignidad de cada uno.
    - **Fase lunar de Rudhyar** (`luna.rudhyar`) como dato principal, con la iluminación como dato secundario.
    - **Luna nueva o llena prenatal** y **eclipses prenatales** de Sol y de Luna (`natal.prenatal`). De cada uno: grado, signo, casa y fecha. La fecha llega en `timestamp` UTC: conviértela a la zona del firmamento.
11. **Notas y lectura IA.** Si la app ya muestra notas, van aquí. Si no, deja el hueco para un prompt futuro; no implementes el cobro de la nota IA sin preguntar.
12. **Plegables, cerrados por defecto:** «Cómo se calculó».
    - Zona y desfase, más «horario de verano» si `zona.horario_verano`.
    - Sistema de casas y «zodiaco tropical».
    - Fuente de efemérides: «VSOP87 · Plutón y Quirón de JPL Horizons».
    - La **tabla de orbes**, armada con `orbes` y `clases_orbe`.

**Rueda natal (`CustomPainter`).** Es la pieza más delicada; replica la de la web:

- **Orientación.** El Ascendente va a la izquierda y el zodiaco corre en sentido antihorario. El ángulo en pantalla es `180° − (longitud − asc)`.
- **Anillo zodiacal.** Doce sectores con el color de su **elemento** a baja opacidad (tabla de abajo) y el glifo del signo en su color.
- **Cúspides.** Las intermedias, finas y tenues. Los ejes **AC–DC** y **MC–IC**, más gruesos, con su rótulo fuera del anillo (AC y MC llenos; DC e IC algo atenuados).
- **Números de casa.** Pequeños y tenues, en la mitad de cada sector, no sobre la cúspide.
- **Anticolisión de glifos.** Ordena los cuerpos por ángulo y corta el anillo por el hueco más grande. Empuja hacia delante a los que queden a menos de la separación mínima (unos 12,5°) y devuelve el grupo a su centro de masa.
  - Cada glifo desplazado lleva una línea guía fina hasta su grado real en el borde interior del anillo.
  - Es el mismo algoritmo de `celestialWindows/resources/views/components/carta-rueda.blade.php`; léelo.
- **Etiqueta junto a cada glifo.** En columna hacia el centro: grado, glifo del signo y minutos, con una «R» pequeña si está retrógrado. Va en letra pequeña y en color tenue.
- **Círculo de aspectos amplio**, alrededor del 45 % del radio y no comprimido en el centro.
  - Las líneas van entre los grados **reales**, no entre los glifos desplazados.
  - Mayores en línea continua con su `color`; menores punteados y tenues.
  - El grosor y la opacidad crecen con `exactitud`.
- **Interacción.** Tocar un planeta resalta sus aspectos y atenúa el resto; tocar fuera lo limpia. Desde la lista o la grilla se resalta un par.
- **Cuerpos.** Incluye Plutón, Quirón, los nodos y Lilith.
- **Fuente de los glifos.** Comprueba que los glifos astrológicos (♇ ⚷ ☊ ☋ ⚸ y los signos) se vean en Android. Si alguno sale como cuadro, usa el selector de texto U+FE0E (como hace `ZodiacTables::asText()` en el servidor) o una fuente de símbolos ya incluida. No añadas una fuente nueva sin preguntar.

**Tests:**

- Con el JSON de ejemplo del final, la pantalla muestra la cuadratura angular, el pequeño gran trígono, a Venus con el badge Exilio y a Marte con OOB.
- La rueda pinta 14 cuerpos sin glifos encimados (distancia angular mínima entre posiciones desplazadas ≥ la separación).

## Fase 3 — Recalcular con la zona del lugar

1. El botón del aviso llama a `PATCH /api/user/charts/{id}/zona` con `{timezone: zona.sugerida.timezone}`. Primero pide confirmación: «El Ascendente y las casas van a cambiar. ¿Recalcular?».
2. La respuesta trae el detalle completo en `data`: repinta con él y muestra el `message`.
3. Throttle de 10/min: desactiva el botón mientras espera.
4. Tests: el PATCH manda el nombre IANA y la pantalla se refresca con la respuesta.

## Fase 4 — Observatorio: Cielos

1. **Navegación.** Una entrada **Observatorio** abre **Cielos**, con un conmutador visible para ir a **Firmamentos** y volver.
2. **Datos.** `GET /api/observatorio` da una tarjeta por favorito en `lugares`.
3. **Tarjeta:**
   - título;
   - icono según `codigo_wmo` y `es_de_dia`;
   - temperatura grande, viento, humedad y precipitación;
   - el distintivo «clima de reserva» si `reserva`;
   - si `clima` es null, la tarjeta igual, con guiones.
4. **Pie de tarjeta según `estudio`:**
   - `null` → «Estudiar este cielo · {precios.estudio_anual} ✨/año» (sin precio si llega 0). Con confirmación, hace `POST /api/favoritos/{id}/estudio`.
   - `activo` → «Ver estudio» y «vence {expira}», más «Renovar» si `renovable`.
   - inactivo → «Estudio en pausa · lo capturado queda», más «Renovar» (si `renovable`) y «Ver lo capturado».
5. **Huérfanos.** Los `huerfanos` van al final, en una tarjeta simple «El lugar ya no está en tus favoritos» con acceso al detalle.
6. **Saldo.** Tras contratar o renovar, actualiza el saldo visible con el `saldo` de la respuesta.

## Fase 5 — Detalle del estudio

1. **Cabecera.** Sale de `GET /api/estudios/{id}`: título, estado, rango de fechas y total de capturas. Si está en pausa, un aviso arriba («renueva para reanudar la captura») que no bloquea nada.
2. **Resumen de 14 días.** Sale de `GET /api/estudios/{id}/resumen`:
   - El texto `resumen`, tal cual.
   - **KPI:** máxima y mínima (con su `fecha`), lluvia total y días con lluvia («aprox.» si `aprox`), y la tendencia de presión (`delta` con flecha según `dir`).
   - La **cobertura**: «{n} de {total} turnos con clima ({pct} %)».
   - **Rango diario contra la normal.** Por cada día de `dias`, una barra vertical de `tmin` a `tmax` y, detrás, la banda de la normal (`normal[0]` a `normal[1]`). La `anomalia`, con signo y en color cálido o frío. Los días sin datos quedan como hueco visible. Si `normal` es null, sin banda, con una nota «la normal del lugar aún se está calculando».
   - Lluvia diaria en barras finas.
3. **Capturas.** `GET /api/estudios/{id}/capturas`, paginado y más reciente primero. Una lista agrupada por `fecha_local`, con una fila por `turno`:
   - el turno con su `hora_local` entre paréntesis, por ejemplo «Mañana (07:03)»;
   - la estación (icono y nombre);
   - icono WMO, temperatura, sensación térmica (`st`) si viene, viento con ráfagas (`vr`), humedad y punto de rocío (`punto_rocio`);
   - lluvia de las 6 h (`p6`, o `pp` en capturas viejas);
   - presión.
   - El UV es el máximo **del día**: va una vez por día, nunca en el turno noche.
   - Un turno con `clima: null` es una fila con guiones, sin interpolar.
4. **Astros por captura.** Una sección plegable con una fila por captura y una columna por cuerpo de `astro.cuerpos`:
   - Sol, Luna y los 7 planetas, más **Plutón y Quirón si vienen**, que solo los traen las capturas desde noviembre de 2026.
   - Celda: glifo del signo (`sg`) y altura (`alt`), con ℞ si `r`, atenuada si `sh` es 0. Un cuerpo ausente es «—».
5. **Leyenda de claves** del JSON compacto (también la trae la exportación JSON): ver el contrato.

## Fase 6 — Exportación

1. Botones «Descargar CSV» y «Descargar JSON» en el detalle. Hacen `POST /api/estudios/{id}/exportar/{formato}` tras una confirmación que muestra `precios.descarga` (sin precio si llega 0).
2. La respuesta es el archivo (`Content-Disposition: attachment`). Guárdalo con el flujo de descargas de la plataforma y ofrece compartir.
3. Un `422` es «te falta polvo»: muestra el `message` y no descuentes nada localmente.
4. El cobro es por descarga: no caches el archivo para repetir descargas gratis.

## Fase 7 — Verificación y cierre

1. `flutter analyze` en 0 y `flutter test` en verde.
2. Prueba en un Android real con la carta de ejemplo, creada desde la app con la zona sugerida:
   - capturas de pantalla del detalle completo (rueda, posiciones, aspectos en lista y en grilla, Dominantes);
   - de Cielos y del detalle de un estudio.
3. Compara esas capturas con la app actual pantalla por pantalla: fondos, tarjetas, tipografía, chips y glifos tienen que verse de la misma familia. Ajusta hasta que no se note qué es nuevo.
4. Cierra con un resumen: qué quedó, qué textos nuevos hay (para la traducción) y qué no se pudo probar.
5. Pregunta antes de commitear y propón un commit por fase.

---

## Contrato que se usa (implementado en el servidor)

Todas las rutas con `auth:sanctum` (Bearer). El detalle de cada tipo está en `docs/api-app-movil.md`.

| Método y ruta | Uso |
|---|---|
| `GET /api/user/zona?lat&lon&fecha&hora` | `{success, timezone, desfase, rotulo, horario_verano}`: la zona del lugar para el alta. Throttle 30/min |
| `POST /api/user/charts` | `{titulo, birth_date, birth_time, birth_lat, birth_lon, timezone?}`. Sin `timezone`, el servidor usa la del lugar. **201** `{success, message, data: {carta_astral, chart_data, firmamento}}`. 409 si es duplicado, 422 si un campo es inválido |
| `GET /api/user/charts` | Listado; cada `Carta` trae `timezone`, `tz_offset` y `tz_revisar` |
| `GET /api/user/charts/{id}` | `data.firmamento` (más los campos de siempre). Si la carta era del motor anterior, el servidor la recalcula antes de responder |
| `PATCH /api/user/charts/{id}/zona` | `{timezone}` (IANA) → `{success, message, data: <detalle>}`. Throttle 10/min; 404 si es ajena |
| `DELETE /api/user/charts/{id}` | Sin cambios |
| `GET /api/observatorio` | `{success, saldo, precios, lugares, huerfanos}` |
| `POST /api/favoritos/{favorito}/estudio` · `POST /api/estudios/{id}/renovar` | `{success, saldo, estudio}` · throttle 10/min |
| `GET /api/estudios/{id}` | Cabecera del estudio |
| `GET /api/estudios/{id}/resumen` | `{success, dias_ventana, hay_clima, cobertura, normal, kpis, resumen, dias[]}` |
| `GET /api/estudios/{id}/capturas?desde&hasta&por_pagina` | `{success, capturas[], paginacion}` (máx. 200 por página) |
| `POST /api/estudios/{id}/exportar/{csv\|json}` | El archivo · throttle 6/min |

**`firmamento`, en resumen:**

```
motor, zona {timezone, desfase, rotulo, horario_verano, revisar, sugerida|null},
sistema_casas, cuspides[12], ejes {asc|mc|dsc|ic: {longitud, signo, grado_en_signo}},
cuerpos [{clave, nombre, simbolo, color, longitud, signo, grado_en_signo, casa,
          retrogrado, estacionario, fuera_de_limites, declinacion, velocidad,
          dignidad {type, modern}|null, es_punto}],
aspectos [{a, b, tipo, nombre, simbolo, color, orbe, orbe_dm, exactitud, aplicativo, grupo}],
figuras [{tipo, etiqueta, detalle|null, cuerpos, asociados, color}],
reparto {elements, modalities: {nombre: {weight, count, color, frac}}, total},
luna {rudhyar, elongacion, iluminacion},
natal {big_three, chart_ruler, sect, angular, tight_aspects, dominant, strongest,
       dignities, house_rulers, hemispheres, prenatal},
orbes [{nombre, simbolo, orbes[5]}], clases_orbe[5]
```

## Tablas que la app necesita (no vienen en la API)

**Signos** (`signo` es el índice 0-11):

| # | Nombre | Glifo | Color | Elemento | Modalidad |
|---|---|---|---|---|---|
| 0 | Aries | ♈ | `#ff6b6b` | Fuego | Cardinal |
| 1 | Tauro | ♉ | `#51cf66` | Tierra | Fijo |
| 2 | Géminis | ♊ | `#ffd43b` | Aire | Mutable |
| 3 | Cáncer | ♋ | `#74c0fc` | Agua | Cardinal |
| 4 | Leo | ♌ | `#ff8cc8` | Fuego | Fijo |
| 5 | Virgo | ♍ | `#69db7c` | Tierra | Mutable |
| 6 | Libra | ♎ | `#91a7ff` | Aire | Cardinal |
| 7 | Escorpio | ♏ | `#b86b6b` | Agua | Fijo |
| 8 | Sagitario | ♐ | `#ffa94d` | Fuego | Mutable |
| 9 | Capricornio | ♑ | `#8ce99a` | Tierra | Cardinal |
| 10 | Acuario | ♒ | `#74c0fc` | Aire | Fijo |
| 11 | Piscis | ♓ | `#d0bfff` | Agua | Mutable |

**Elementos** (anillo de la rueda y barras del reparto): Fuego `#f0783c`, Tierra `#7bbf6a`, Aire `#e8c34a`, Agua `#5aa6d8`. El reparto ya trae su `color`.

**Badges:**

- Domicilio `#5fd48a`
- Exaltación `#f5d76e`
- Exilio `#ff9a3c`
- Caída `#ff5d5d`
- R `#ff9e8a`
- E `#9fb0c4`
- OOB `#c9a0ff`

Son los mismos tonos de los aspectos; no hay colores nuevos.

**Ejes:** AC y DC `#c4b5fd`; MC e IC `#f0abfc`.

**Fase de Rudhyar** (`luna.rudhyar`):

- `new` → Nueva
- `crescent` → Creciente
- `first_quarter` → Cuarto creciente
- `gibbous` → Gibosa
- `full` → Llena
- `disseminating` → Diseminante
- `last_quarter` → Cuarto menguante
- `balsamic` → Balsámica

**Casas en romano:** I a XII.

## Carta de ejemplo para tests y capturas

- **Datos.** Santiago (−33.4489, −70.6693), 07/04/2021 a las 12:33, guardada en **UTC**, que es como estaba la original. Con esos datos el detalle debe traer:
  - `zona.revisar: true`, sugerida `America/Santiago` `UTC−04:00`;
  - figuras `angular` («Saturno/MC – Urano/AC») y `small_grand_trine` (Venus, Marte, Júpiter, con Sol y Luna asociados);
  - regente Venus, en Aries, casa XII, `detriment`;
  - carta diurna, Rudhyar `last_quarter` y Marte `fuera_de_limites`;
  - sin aspecto Marte–Nodo Norte;
  - Luna sextil Venus a 4°45′.
- **Fixture.** Graba la respuesta real de `GET /api/user/charts/{id}` de esa carta como JSON en `test/fixtures/` para los tests de widgets, quitando antes `carta_astral` (trae datos de nacimiento) y dejando solo `firmamento`.

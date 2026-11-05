# Contrato servidor ↔ app móvil

> Fuente de verdad para la app Flutter (`demeter`). Si el código y este
> documento no coinciden, manda el código y se corrige el documento.

## Índice de rutas

API en `https://windowsdemeter.com/api`. Las páginas del WebView cuelgan de
`https://windowsdemeter.com`.

| Ruta | Auth | Para qué |
|---|---|---|
| `POST /api/register` · `POST /api/login` · `POST /api/login/2fa` · `POST /api/login/google` | — | [Sesión](#sesión) |
| `GET /api/me` · `POST /api/logout` | Bearer | [Sesión](#sesión) |
| `GET /app/mapa/{modo}` | — | [Mapa del invitado](#mapa-en-webview) |
| `POST /api/app/vista` → `/app/mapa/t/{token}/{modo}[/f/{id}]` | Bearer | [Mapa del usuario](#token-de-vista) |
| `GET/POST/PATCH/DELETE /api/favoritos…` | Bearer | [Favoritos y su paisaje](#favoritos) |
| `GET /api/paisajes` · `POST /api/paisajes/{clave}/comprar` | Bearer | [Mis paisajes](#paisajes-mis-paisajes) |
| `GET/POST/DELETE /api/favoritos/{id}/fondo…` | Bearer | [Live wallpaper](#fondo-animado-live-wallpaper) (`/lively/m/{token}/{modo}`) |
| `POST/DELETE /api/dispositivos` | Bearer | [Push](#dispositivos-y-push) |
| `GET/POST /api/avisos…` · `GET/PUT /api/avisos/preferencias` | Bearer | [Avisos](#avisos) |
| `GET /api/store/packages?plataforma=android` · `POST /api/store/google-play/verificar` | Bearer | [Comprar polvo](#compras-con-google-play) |
| `/api/user/profile…` · `/api/user/referral` | Bearer | [Perfil y cuenta](#perfil-y-cuenta) |
| `/api/user/charts…` · `PATCH /api/user/charts/{id}/zona` · `GET /api/user/zona` · `/api/user/history…` | Bearer | [Cartas e historial](#cartas-astrales-e-historial) |
| `GET /api/observatorio` · `/api/favoritos/{id}/estudio` · `/api/estudios/{id}…` | Bearer | [Observatorio](#observatorio-y-estudios-del-cielo) |
| `POST /api/oraculo/consultar` · `POST /api/oraculo/compatibilidad` | Bearer | [Oráculo](#oráculo) |

Las [rutas antiguas](#rutas-antiguas-solo-la-app-publicada) siguen vivas para
la versión publicada, pero la app nueva no las usa.

## Reglas generales

- **Token:** `Authorization: Bearer <access_token>`. Es opaco (hoy con la forma
  `<id>|wdm_…`): la app lo guarda y lo manda entero, sin interpretarlo. Dura
  **365 días** desde que se emite; usarlo no lo renueva. Cuando vence, la API
  responde 401.
- **`device_name`:** un identificador por instalación (por ejemplo un UUID que la
  app genera la primera vez y guarda). Volver a entrar con el mismo
  `device_name` revoca los tokens anteriores **de esa cuenta** en esa
  instalación. Si entra otra cuenta, el token de la anterior sigue vivo: llamar
  a `POST /api/logout` antes de cambiar de cuenta.
- **Siempre JSON**, mande o no `Accept`. Conviene mandar
  `Accept: application/json` igual.
- **Idioma:** los `message`, los textos del catálogo (p. ej. los paisajes) y
  los avisos (`titulo`, `texto`, etiquetas de las preferencias) salen en el
  idioma del `Accept-Language` que mande la app (`?lang=` manda más, si la
  ruta lo acepta). Los avisos se guardan como clave + parámetros y se redactan
  en cada petición: el mismo aviso cambia de idioma con la cabecera. Hoy solo
  existe español: cualquier otro idioma cae al español sin error, así que la
  app puede mandar la cabecera desde ya.
- **Cabeceras:** toda respuesta de una ruta de la API, también el 401 y el 429,
  lleva `X-Content-Type-Options: nosniff` y `Cache-Control: no-store, private`.
  Solo salen sin ellas el 404 de una ruta que no existe y el 503 de
  mantenimiento. La app no debe cachear respuestas con token.
- **Tres formas de respuesta.** Las de sesión (`login`, `login/2fa`,
  `login/google`, `register`, `me`) y la de `app/vista` devuelven el objeto sin
  envoltorio. Las rutas antiguas usan `{status: "success", data}`. Las nuevas
  usan `{success: true, …}`. Se documentan tal como son; no hay que unificarlas
  en la app.

### Errores

| Código | Cuerpo | Qué hace la app |
|---|---|---|
| **400** | `{success: false, error}` | Solo en el oráculo (ver ahí) |
| **401** | `{message}` (`"Unauthenticated."` sin token o con uno vencido; en los logins, el motivo) | Sin sesión: borrar el token y volver al mapa de invitado con «Entrar al portal». En un login: mostrar `message` |
| **403** | `{message}` o `{success: false, message}` | Algo ajeno o no permitido. En el oráculo, falta de saldo (ver ahí) |
| **404** | `{message}` | No existe o no es suyo. El `message` no es para el usuario |
| **409** | `{success: false, message, …}` | Duplicado (carta astral repetida) |
| **422** | Validación: `{message, errors: {campo: [textos]}}`. Negocio: `{success: false, message}` | Mostrar `message` (o el primer texto de `errors`) |
| **429** | `{message: "Too Many Attempts."}` con `Retry-After` (segundos) | Esperar `Retry-After` antes de reintentar |
| **500** | `{message: "Error interno del servidor."}`, salvo donde la sección diga otra cosa (cartas, oráculo) | Mensaje genérico. El detalle queda en el log del servidor |
| **503** | `{success: false, message}` | En Google Play: reintentar más tarde |
| **503** | `{message: "Service Unavailable"}` con `Retry-After: 30` | Mantenimiento durante un deploy (el WebView recibe una página HTML 503). Reintentar tras `Retry-After` |

### Límites

| Qué | Límite |
|---|---|
| Toda la API | 60/min por usuario (o por IP sin sesión) |
| `POST /api/login` | 5/min por correo e IP, y 20/min por IP |
| `POST /api/login/google` | 5/min por IP (no lleva correo), y el tope de 20/min por IP compartido con `/login` |
| `POST /api/login/2fa` | 5/min por desafío y 10/min por IP |
| `POST /api/register` | 5/min por IP |
| `/api/astronomy/map-svg-mobile`, `map-api-mobile`, `sky-data` | 20/min y 1.500/día por IP |
| Páginas `/app/mapa/…`, `/lively/…`, su refresco y las miniaturas de paisaje | 60/min por IP, un solo contador para todas (también la portada) |

Cada sección indica los límites propios de sus rutas. Cada límite de la API
tiene su propio contador, salvo donde se dice que se comparte.

## Sesión

Respuesta de un login correcto (`Sesión`):

```json
{ "access_token": "wdm_…", "token_type": "Bearer",
  "user": { "id": 7, "name": "…", "email": "…", "celestial_coins": 500, "referral_code": "CELEST-AB12CD",
            "has_password": false, "email_verified": true, "regalo_pendiente": false,
            "created_at": "2026-10-01T12:00:00.000000Z" } }
```

| Ruta | Cuerpo | Respuesta |
|---|---|---|
| `POST /api/login` | `{email, password, device_name}` | `Sesión`, o `{two_factor: true, desafio}` si la cuenta tiene 2FA. **401** `{message}` si las credenciales no valen (mismo mensaje exista o no el correo) |
| `POST /api/login/2fa` | `{desafio, code \| recovery_code, device_name}` | `Sesión`. **422** `{message}` si el código no vale o el desafío venció (dura 5 minutos): volver al login |
| `POST /api/login/google` | `{id_token, device_name}` | `Sesión`. `id_token` es el **ID token de Firebase** (`user.getIdToken()`), no el access token de Google. **401** `{message}` si no vale o el correo de Google no está verificado. Nunca pide 2FA ni acepta `referral_code` |
| `POST /api/register` | `{name, email, password, password_confirmation, device_name, referral_code?}` | **201** `Sesión` + `message`. Contraseña de 10 caracteres o más, con letras, que no aparezca en filtraciones conocidas |
| `GET /api/me` | — | El `user` de `Sesión`, sin envolver |
| `POST /api/logout` | — | `{message}`. Borra ese token, sus vistas del mapa y los teléfonos registrados con él |

- **Regalo de bienvenida (500 ✨):** llega cuando la identidad está verificada:
  al entrar con Google o con TikTok (web), o al verificar el correo. Mientras
  tanto, `regalo_pendiente` es `true`. **En producción no se envían correos**:
  quien se registra con contraseña se queda en 0 ✨ hasta entrar con Google. La
  app debe empujar el botón de Google. La API no tiene ruta para pedir la
  verificación del correo.
- Con `referral_code`, el invitado recibe 10 ✨ más junto con el regalo. Quien lo
  invitó recibe 25 ✨ con la primera consulta pagada del invitado. El código
  solo entra por `POST /api/register`: quien se registra directamente con
  Google no puede usarlo.
- Si Google se vincula a una cuenta con contraseña cuyo correo no estaba
  verificado, el servidor quita esa contraseña y cierra sus otras sesiones.

## Mapa en WebView

La app no dibuja el mapa: carga en un WebView una página kiosk del servidor con
el mapa del teléfono y su animación (nubes, lluvia, mar, aves), sin barra,
paneles, anuncios ni analítica.

**El refresco.** Cada 5 minutos (alineado al reloj, más 0-15 s al azar) la
página pide `?fragmento=1` a su propia URL y cambia solo el mapa, sin recargar.
Con la página oculta no corre, y se pone al día al volver. Si falla (vista
vencida, 429, sin red), no avisa: el mapa se queda congelado. Por eso la app
renueva la vista guiándose por `expira_at`.

### Rutas

| Ruta | Para quién | Lugar y paisaje |
|---|---|---|
| `GET /app/mapa/{modo}` | sin sesión | `?lat&lon` opcionales. Sin ellos, el último lugar guardado en la cookie `demeter_loc`; si no hay, el aproximado por IP, y si tampoco, Santiago. Paisaje gratis al azar, distinto del de la entrada anterior. |
| `GET /app/mapa/t/{token}/{modo}` | con sesión | Con `?lat&lon` (ubicación actual): si está a menos de 0,0005° de un favorito (unos 50 m), **302** a la URL de ese favorito, que conserva solo `ratio` y `barra`; si no, ese lugar con un paisaje al azar entre los que el usuario puede usar. Sin `lat`/`lon`: el favorito más antiguo. Sin favoritos: al azar. |
| `GET /app/mapa/t/{token}/{modo}/f/{favorito}` | con sesión | Ese favorito (id de `LugarFavorito`), con su paisaje. Si no es del usuario, 404. Ignora `lat`/`lon`. |
| `GET /lively/m/{token}/{modo}` | live wallpaper | El fondo de un favorito con el mapa del teléfono. Token permanente del enlace Lively del favorito (no el de vista). |

- `modo`: `basico`, `profesional` o `astronomico`. En `/lively/m/` también
  `rotativo`: un paisaje distinto cada 5 min, en orden fijo y no al azar. Se
  desbloquea por favorito (con el cobro apagado y para los admins es libre); sin
  desbloquear, 404.
- `?ratio=` (alto − `barra`) ÷ ancho del WebView, en px CSS, de 1.5 a 2.4 (se
  acota). Mandarlo siempre: sin él, o si difiere en 0,1 o más de lo que la
  página mide, la página se recarga una vez.
- `?barra=` px que tapa una barra del sistema abajo (0 por defecto, máx. 200).
- Las respuestas llevan `X-Robots-Tag: noindex` (el 302 no). No abren sesión,
  pero escriben cookies: `demeter_ratio` y, en el mapa del invitado,
  `demeter_paisaje_app` (cifrada, 30 días), que es lo que evita repetir el
  paisaje. El WebView debe aceptar cookies.

### Token de vista

`POST /api/app/vista` con `Authorization: Bearer <token de Sanctum>` (límite 10/min).

```json
201 { "token": "40 alfanuméricos", "expira_en": 86400, "expira_at": "2026-10-23T01:00:00+00:00",
      "base_url": "https://windowsdemeter.com/app/mapa/t/<token>" }
```

- La app arma `base_url + "/" + modo` (y `+ "/f/" + id` para un favorito).
- Dura 24 h (`APP_VISTA_HORAS`), nunca más que el token de Sanctum. Pedir uno
  nuevo al abrir la app o cuando le quede menos de 1 h, y recargar el WebView
  con la URL nueva: el refresco sigue usando la URL con la que se abrió.
- Cerrar sesión (`POST /api/logout`) o revocar el token de Sanctum borra sus
  vistas al instante. Una vista vencida, revocada o desconocida da **404**.
- Con la sesión web (cookie) en vez del Bearer: 401.

### Privacidad

- El token va en el path y no en la query porque el refresco de 5 minutos
  borra la query salvo `lat`, `lon`, `ratio` y `paisaje`.
- En las rutas con token, las coordenadas de un favorito no salen nunca: ni en
  la URL, ni en la página, ni escritas en el mapa (la cabecera muestra sólo el
  nombre del lugar). Tampoco el lugar que el servidor resolvió por su cuenta.
  Ojo: un favorito creado sin nombre antes de esta versión puede tener como
  título sus coordenadas con 2 decimales. Los nuevos se llaman «Mi lugar N».
- La ubicación actual que la app manda en `?lat&lon` sí vuelve en el refresco,
  porque ya iba en esa URL. Si es un favorito, el 302 la saca de la URL.
- En el mapa del invitado, el lugar aproximado (por la cookie o por IP) sí
  aparece en la página, escrito en la cabecera del mapa con 3 decimales y en la
  URL del refresco. Es la ubicación aproximada de quien mira, no un favorito.

### Animaciones y «quitar animaciones» de Android

La página respeta `prefers-reduced-motion`. En Android, *Ajustes →
Accesibilidad → Quitar animaciones* lo activa en el WebView: el mar vivo no
arranca, las aves y los aviones no salen, y las nubes y la lluvia quedan
quietas. Es a propósito; la app no debe forzarlo.

## Favoritos, paisajes, fondo, push y avisos

Todo con `Authorization: Bearer <token de Sanctum>`. Sin token: **401**.
Los errores de negocio responden **422** con `{success: false, message}`: el
`message` está escrito para el usuario y la app lo muestra tal cual.

### Favoritos

Los mismos controladores que la web; un favorito ajeno da **403**.

| Ruta | Cuerpo | Respuesta |
|---|---|---|
| `GET /api/favoritos` | — | `{success, favoritos: [Favorito]}`, del más antiguo al más nuevo |
| `POST /api/favoritos` | `{lat, lon, titulo? (máx. 60)}` | **201** nuevo o **200** si ese punto ya estaba (mismas coordenadas a 4 decimales): `{success, existente, favorito}`. Tope de **20** favoritos: 422. Límite 30/min |
| `PATCH /api/favoritos/{id}` | `{titulo}` (máx. 60) | `{success, favorito}` |
| `DELETE /api/favoritos/{id}` | — | `{success}` |
| `GET /api/favoritos/{id}/paisaje` | — | `{success, paisaje, catalogo}` |
| `PATCH /api/favoritos/{id}/paisaje` | `{paisaje: clave \| null}` | `{success, favorito, paisaje}`. Límite 30/min (junto con el POST) |

- `Favorito`: `{id, titulo, lat, lon, paisaje_id, ajustes}`. Las coordenadas se
  guardan a 4 decimales. Un `titulo` de más de 60 caracteres da 422 (no se
  recorta).
- Sin `titulo`, el servidor pone el nombre del lugar. Si no encuentra uno, el
  título es «Mi lugar N» (N = los favoritos que ya tenía + 1), nunca las
  coordenadas.
- `paisaje_id` es un id interno que el catálogo no publica: la clave del
  paisaje de un favorito sale de `GET …/{id}/paisaje` (`paisaje`) o de la
  respuesta del `PATCH`.
- `ajustes` está reservado y hoy llega siempre como `[]` (lista vacía). Leerlo
  aceptando lista u objeto.
- `paisaje` es la clave del paisaje elegido, o `null` para el de siempre
  (el por defecto). Mandar `null` o la clave del por defecto es lo mismo.
- El `catalogo` de `GET …/paisaje` tiene la forma de la web: la app usa el de
  `GET /api/paisajes`.
- Un paisaje bloqueado o que no existe: 422 «Ese paisaje no está disponible.».
- **Borrar un favorito borra también su fondo animado** (corta el live
  wallpaper y el Lively del PC) y el rotativo que se compró para él. La app
  debe avisarlo antes de borrar.

### Paisajes («Mis paisajes»)

`GET /api/paisajes`:

```json
{ "success": true, "saldo": 1000, "momentos": ["amanecer", "mediodia", "tarde", "noche"],
  "paisajes": [{ "clave": "castillo-wulff", "titulo": "Castillo Wulff", "descripcion": "…",
                 "es_defecto": false, "es_premium": true, "precio_polvo": 100,
                 "comprado": false, "puede_usar": false,
                 "miniatura_url": "https://windowsdemeter.com/paisajes/castillo-wulff/miniatura" }] }
```

- Los paisajes llegan en el orden que fija el admin: la app los muestra en ese
  orden.
- El candado 🔒 va donde `puede_usar` es `false`. `es_premium` puede ser `true`
  con `puede_usar` `true`: con el cobro apagado todo está abierto, y los admins
  lo usan todo.
- `miniatura_url` es pública (sin token): un SVG con `ETag`
  (`If-None-Match` → 304) y `Cache-Control: public, max-age=3600`. El `ETag`
  cambia una vez al día. Admite `?momento=` con un valor de `momentos`; sin él,
  o con uno que no existe, `tarde`. Una clave que no está publicada da 404.
- Las miniaturas comparten el límite de 60/min por IP con `/app/mapa` y
  `/lively/m`: la app debe guardarlas en caché.

`POST /api/paisajes/{clave}/comprar` (límite 10/min, compartido con
`…/fondo/rotativo`) → `{success, saldo, paisaje}`
con el saldo nuevo y el paisaje ya con `comprado: true`. Pago único, sin
caducidad. 422 si falta polvo, si ya lo puede usar, si no está a la venta o si
el cobro está apagado.

### Fondo animado (live wallpaper)

| Ruta | Respuesta |
|---|---|
| `GET /api/favoritos/{id}/fondo` | `Fondo` |
| `POST /api/favoritos/{id}/fondo` | **201** si lo crea, **200** si ya existía: `Fondo` |
| `POST /api/favoritos/{id}/fondo/regenerar` | `Fondo` con un token nuevo; el anterior da 404 al instante. Sin fondo, lo crea (también con 200) |
| `DELETE /api/favoritos/{id}/fondo` | `Fondo` con `existe: false` |
| `POST /api/favoritos/{id}/fondo/rotativo` | Desbloquea el rotativo de ese favorito: `Fondo` más `saldo` (el nuevo). Límite 10/min, compartido con la compra de paisajes |

```json
{ "success": true, "existe": true,
  "urls": { "basico": "https://…/lively/m/<token>/basico", "profesional": "…", "astronomico": "…", "rotativo": "…" },
  "puede_crear": true, "rotativo": { "desbloqueado": true, "precio": 200 },
  "ultimo_uso_at": "2026-10-23T15:00:00+00:00" }
```

- Sin fondo, `urls` es `{}` (objeto vacío, nunca lista).
- `rotativo` sale en `urls` sólo si está desbloqueado. Se desbloquea por
  favorito, con pago único de `rotativo.precio` ✨ (200), desde la app o desde la
  web (*Ajustes → Fondos Lively*). Se puede comprar antes de crear el fondo:
  la URL aparece al crearlo. 422 si falta polvo, si ya lo tiene o si el cobro
  está apagado (entonces lo tiene todo el mundo).
- `puede_crear: false` → el `POST` responde 422 si aún no hay fondo (con uno
  ya creado responde 200). Hoy vale siempre `true`.
- `ultimo_uso_at` es `null` sin fondo, si nunca se usó o justo después de
  regenerarlo. Se actualiza como mucho una vez por hora.
- El token es el del **enlace Lively del favorito**, el mismo de
  `/lively/f/{token}/{modo}` en Windows. Regenerar o borrar desde la app corta
  también el fondo de Lively en el PC.
- La app añade `?ratio=` (alto ÷ ancho) a la URL. Los POST y DELETE van con
  límite 10/min.

### Dispositivos y push

`POST /api/dispositivos` `{fcm_token (20 a 4096 caracteres), plataforma: "android" | "ios", version_app? (máx. 20)}`
→ `{success}`: **201** alta, **200** si ese token ya estaba (se actualiza y, si
era de otra cuenta, pasa a esta). Hay que mandarlo con el Bearer de la app: con
la sesión web da 401. Límite 10/min.

- Registrarlo al iniciar sesión, al abrir la app y en `onTokenRefresh`.
- `DELETE /api/dispositivos` `{fcm_token}` al cerrar sesión → `{success}`, 200
  aunque no exista. Solo borra el token si es de esta cuenta. Sin `fcm_token`,
  422. `POST /api/logout` también borra los teléfonos registrados con ese token.
- El token FCM se guarda cifrado. Si FCM lo da por inválido o desconocido, el
  servidor lo borra: la app lo vuelve a registrar al abrirse.
- El push solo sale si el servidor lo tiene encendido (`ALERTAS_PUSH=true`).
  Apagado, los avisos aparecen igual en `GET /api/avisos`.

**El push de un aviso:**

```json
{ "notification": { "title": "<titulo>", "body": "<texto>" },
  "data": { "aviso_id": "<uuid>", "tipo": "lluvia", "titulo": "<titulo>", "texto": "<texto>" },
  "android": { "priority": "high", "notification": { "channel_id": "alertas", "visibility": "PRIVATE" } } }
```

- Sin coordenadas. `titulo` y `texto` pueden nombrar el lugar favorito; por
  eso la visibilidad es privada: si el usuario pidió ocultar el contenido
  sensible en la pantalla de bloqueo, Android no los enseña ahí.
- `title`, `body`, `titulo` y `texto` van en el idioma del dueño de la cuenta
  (`users.locale`, que llega con el selector de idioma); mientras no lo haya
  fijado, en español. No dependen del `Accept-Language` de ninguna petición.
- La app crea el canal de Android con id **`alertas`** (nombre «Alertas»). El
  servidor puede cambiar el id con `APP_PUSH_CANAL_ANDROID`; si cambia, cambia
  también la app.
- **Con la app abierta**, Android no muestra la notificación: llega a
  `onMessage` y la app la construye ella con el canal `alertas` y visibilidad
  privada, a partir de `data`.
- `aviso_id` es el `id` de `GET /api/avisos`: al tocar la notificación, abrir
  ese aviso y marcarlo con `POST /api/avisos/{aviso_id}/leido`.
- `tipo`: `lluvia`, `helada`, `ciclon`, `sismo`, `inundacion`, `volcan`,
  `incendio`, `luna`, `eclipse_lunar`, `eclipse_solar`, `retrogrado`,
  `ingreso`, y `prueba` para el aviso de prueba
  (`php artisan alertas:push-prueba {id}`).
- En iOS sale la notificación sin `android`; hace falta la clave APNs en Firebase.
  El payload no lleva bloque `apns` (ni `sound`): sin probar en un iPhone,
  puede llegar sin sonido.

### Avisos

| Ruta | Respuesta |
|---|---|
| `GET /api/avisos` | `{success, no_leidos, avisos: [Aviso]}`: los vigentes, del más nuevo al más viejo (máx. 20) |
| `POST /api/avisos/{id}/leido` | `{success, pendientes}`; 404 `{success: false, pendientes}` si no es suyo |
| `POST /api/avisos/leidos` | `{success}` |
| `GET /api/avisos/preferencias` | `Preferencias` |
| `PUT /api/avisos/preferencias` `{tipo, activo}` | `Preferencias`; 422 si el tipo no existe |

- `Aviso`: `{id, tipo, titulo, texto, lugar, lat, lon, fecha_objetivo,
  expira_en, url, fuente, leido, creado_en}`. `titulo` y `texto` se redactan
  en el idioma de la petición (ver «Idioma»). Las coordenadas son las del
  favorito del propio usuario. Los avisos que no son de un lugar (los
  astrológicos generales y el de `prueba`) llegan con `lugar: ""` y
  `lat`/`lon` en `null`.
- `no_leidos` cuenta los no leídos de la lista (los vigentes, máx. 20).
  `pendientes` cuenta todos los no leídos, también los vencidos: no son el
  mismo número.
- `Preferencias`:

```json
{ "success": true, "tiene_favoritos": false,
  "suscripciones": { "lluvia": false, "helada": true },
  "secciones": [{ "clave": "clima", "titulo": "Alertas climáticas", "texto": "…",
                  "avisos": [{ "tipo": "lluvia", "etiqueta": "…", "descripcion": "…", "activo": false }] },
                { "clave": "catastrofes", "titulo": "Catástrofes en curso", "texto": "…", "avisos": [] },
                { "clave": "astrologicos", "titulo": "Avisos astrológicos", "texto": "…", "avisos": [] }] }
```

- Las tres secciones van siempre en ese orden, con los nombres de la web.
  Cada alerta está en una sola sección.
- El `texto` de «Catástrofes en curso» incluye el aviso legal de GDACS: se
  muestra siempre.
- Tener favoritos es requisito: con `tiene_favoritos: false` se puede
  suscribir, pero no llega ningún aviso. La app muestra un aviso que lleva a
  crear un favorito.
- Todas vienen apagadas. Las nuevas aparecen solas en su sección.
- Una alerta que el admin apagó en `/admin/alertas` sigue en la lista y se
  puede activar, pero no avisa mientras siga apagada.

## Compras con Google Play

La app de Android compra el polvo con Google Play Billing y **no muestra Mercado
Pago**. El servidor confirma cada compra con Google antes de acreditarla. Todo
va con `Authorization: Bearer <token de Sanctum>`.

### Paquetes

`GET /api/store/packages?plataforma=android`:

```json
{ "status": "success",
  "obfuscated_account_id": "64 hex",
  "data": [{ "id": 2, "name": "Popular", "coins": 100, "price_clp": 3490, "currency": "CLP",
             "icon": "star", "color": "purple", "description": "…", "highlight": false,
             "google_play_product_id": "polvo_100" }] }
```

- Solo vienen los paquetes que se venden en Play: `polvo_50`, `polvo_100` y
  `polvo_1000`.
- **El precio que se muestra es el de Play** (`ProductDetails` de
  `google_play_product_id`), no `price_clp`: ese es el de la web.
- `obfuscated_account_id` va **siempre** en
  `BillingFlowParams.setObfuscatedAccountId(...)`. Sin él, o con el de otra
  cuenta, el servidor rechaza la compra. Es fijo para cada usuario mientras no
  cambie el `APP_KEY` del servidor: pedirlo de nuevo antes de cada compra, no
  guardarlo.
- Sin `plataforma=android` la respuesta es la de siempre (Mercado Pago, versiones
  antiguas de la app).

### Verificar una compra

`POST /api/store/google-play/verificar` `{product_id, purchase_token}` (límite 20/min).

| Respuesta | Qué pasó | Qué hace la app |
|---|---|---|
| **200** `{success, acreditado: true, pendiente: false, polvo, saldo}` | Acreditada ahora | **Consumir** la compra y mostrar el saldo |
| **200** `{success, acreditado: false, pendiente: false, polvo, saldo}` | Ya estaba acreditada (reintento) | **Consumir**. No se suma nada |
| **202** `{success, acreditado: false, pendiente: true, polvo, saldo}` | Pago pendiente en Google (efectivo, etc.) | **No consumir**. Volver a mandarla cuando Play la avise como comprada |
| **422** `{success: false, message}` | Rechazada: paquete que no se vende, token que Google no reconoce, compra de otro paquete o de otra cuenta, o cancelada | **No consumir**. Mostrar `message` |
| **503** `{success: false, message}` | No se pudo confirmar con Google (no respondió, falló la cuenta de servicio o la base) | **No consumir**. Reintentar más tarde y mostrar `message` |

- **Solo se consume con 200.** Después de un 202, un 422 o un 503, la compra
  queda en Play y la app la vuelve a mandar.
- Al abrir la app, `queryPurchasesAsync(INAPP)` y mandar al servidor cada compra
  sin consumir. Si la app se cerró entre el OK y el consumo, el reintento
  responde 200 con `acreditado: false` y la app la consume.
- Un mismo `purchase_token` acredita **una sola vez**. Una vez acreditado,
  repetirlo no suma polvo ni vuelve a preguntar a Google. Una compra pendiente
  no se guarda: cada reintento vuelve a preguntar.
- `polvo` es lo que esa compra da, o lo que dará si está pendiente. Con varias
  unidades se multiplica.
- **El servidor no reconoce (acknowledge) ni consume la compra.** Google
  reembolsa sola la compra que nadie reconoce en 3 días desde que queda
  comprada: la app tiene que consumirla tras el 200.
- Las compras de los testers de licencias **acreditan polvo de verdad**. El
  servidor solo las marca como de prueba.
- Si Google la reembolsa después de acreditada, el polvo no se descuenta.

## Perfil y cuenta

Rutas anteriores a la app nueva: responden `{status: "success", …}` con `data`,
`message` o los dos.

| Ruta | Cuerpo | Respuesta |
|---|---|---|
| `GET /api/user/profile` | — | `data: {id, name, email, celestial_coins, referral_code, has_password, created_at}` |
| `GET /api/user/referral` | — | `data: {referral_code, reward_per_referral, welcome_bonus_for_friend, share_message, register_hint, current_balance}` |
| `PUT /api/user/profile` | `{name?, email?, current_password?}` | `{status, message, data: {id, name, email}}`. Cambiar el correo exige `current_password` y lo deja **sin verificar**. Sin contraseña definida (cuentas de Google): 422 |
| `PUT /api/user/profile/password` | `{password, password_confirmation, current_password?}` | `{status, message}`. Misma regla que el registro. `current_password` solo si ya tenía una. Revoca los **otros** tokens de la app, y con ellos sus teléfonos de push y sus vistas del mapa. Las sesiones web siguen abiertas |
| `DELETE /api/user/profile` | `{password}` | `{status, message}`. Borra la cuenta, sus tokens, cartas, consultas, favoritos y compras. En cuentas sin contraseña el campo es obligatorio pero no se comprueba |

- Para el saldo y los datos de sesión, la app nueva usa `GET /api/me`.
  `/api/user/profile` sigue igual para no romper la app publicada.
- **Correo nuevo sin verificar.** El servidor no manda correo para verificarlo
  (en producción no hay envío). Mientras siga sin verificar, quien entre con
  Google con esa dirección se queda con la cuenta: el servidor borra la
  contraseña y cierra todas las sesiones. La app debe advertirlo antes de
  cambiar el correo.

## Cartas astrales e historial

> De cara al usuario ahora se llaman **"Firmamentos"** (un firmamento = una
> carta astral). El contrato técnico no cambia: rutas, campos y el tipo `Carta`
> siguen igual; sólo los textos visibles (mensajes, pantallas) usan la palabra
> nueva.

| Ruta | Cuerpo | Respuesta |
|---|---|---|
| `GET /api/user/charts` | — | `{status, data: [Carta]}`, de la más nueva a la más vieja |
| `POST /api/user/charts` | `{titulo (máx. 200), birth_date: "AAAA-MM-DD" (no futura), birth_time: "HH:MM", birth_lat (-90 a 90), birth_lon (-180 a 180), timezone}` | **201** `{success, message, data: {carta_astral: Carta, chart_data, firmamento, notas: [], nota_ia_costo}}`. **409** `{success: false, message, existing_chart}` si ya hay una con esa fecha, hora y lugar. **422** `{success: false, errors}` (también una fecha en otro formato o una zona que no existe). **500** `{success: false, message}` si el cálculo falla |
| `GET /api/user/charts/{id}` | — | `{status, data: {carta_astral: Carta, planetary_positions, houses, aspects, firmamento: Firmamento, notas: [NotaFirmamento], nota_ia_costo}}`. Si la carta se calculó con un motor anterior, se recalcula antes de responder (`firmamento.motor` sube) |
| `PATCH /api/user/charts/{id}/zona` | `{timezone}` (nombre IANA; un desfase fijo da 422) | `{success, message, data: <igual que el detalle>}`. Cambia la zona y recalcula: la hora local anotada no cambia. **404** si no es suya. Throttle 10/min |
| `POST /api/user/charts/{id}/notas` | `{contenido}` (máx. 250) | **201** `{success, nota: NotaFirmamento}`. **422** si viene vacía o larga; **404** si no es suya. Throttle 20/min |
| `POST /api/user/charts/{id}/notas/ia` | — | **201** `{success, nuevo_balance, nota: NotaFirmamento}` con `es_ia: true`: la lectura de la IA sobre el firmamento, que cobra `nota_ia_costo` (20) de polvo estelar después de que el proveedor responde. **403** `{success: false, error, insufficient_coins: true, nuevo_balance}` sin saldo; **502** `{success: false, error, nuevo_balance}` si el proveedor falla, sin cobrar; **404** si no es suya. Throttle 5/min |
| `GET /api/user/zona?lat&lon&fecha&hora` | — | `{success, timezone, desfase (s), rotulo ("UTC−04:00"), horario_verano}`: la zona IANA del punto y el desfase que regía esa fecha y hora (por defecto hoy a las 12:00). Throttle 30/min |
| `DELETE /api/user/charts/{id}` | — | `{success, message}`; **404** `{success: false, message}` |
| `GET /api/user/history?page=` | — | `{status, data: <paginador>}`: 15 por página, `data.data` es la lista de `Consulta` |
| `GET /api/user/history/{id}` | — | `{status, data: Consulta}` |
| `DELETE /api/user/history/{id}` | — | `{success, message}`; **404** `{success: false, message}` |

- Las coordenadas se guardan redondeadas a 4 decimales (unos 11 m), y el 409
  compara así.
- `timezone`: **opcional desde nov-2026**. Sin él, el servidor usa la zona
  IANA del lugar (no la del teléfono: los países no usan la hora de su
  longitud y la zona correcta es la del lugar de nacimiento). Si llega, puede
  ser un nombre IANA o un desfase fijo (`UTC`, `UTC-4`, `GMT+5:30`), que es lo
  que manda la app publicada. Otra cosa da 422. El campo se guarda tal como
  llegó, y `Carta.tz_offset` guarda el desfase en segundos que regía ese día.
  El alta (`201`) también devuelve `data.firmamento`.
- `Carta.tz_revisar`: `true` si la carta quedó guardada con una zona que no es
  la del lugar y ese día tenían otro desfase. No se corrige sola: la app lo
  avisa y ofrece `PATCH …/zona` con `firmamento.zona.sugerida.timezone`.
- Las cartas creadas **antes de esta versión** con `UTC-4` o `UTC-3` se
  calcularon en UTC, con 4 o 3 horas de error, porque el servidor no entendía
  esos valores. No se recalcularon.
- `Carta`: `{id, user_id, titulo, birth_date, birth_time, birth_lat, birth_lon,
  timezone, sun_degree … pluto_degree, asc_degree, mc_degree, houses_json,
  aspects_json, chart_data_json, …}`. Es la carta del propio usuario, con sus
  datos de nacimiento. La app no debe mandarlos a ningún otro sitio.
- Tipos de `Carta`: `birth_date` llega como `"AAAA-MM-DDT00:00:00.000000Z"`,
  `birth_time` como `"HH:MM"`, y las coordenadas y los `*_degree` como
  **textos** decimales (`"-33.4489000"`, `"123.45"`): convertirlos al leer.
  `pluto_degree` (y `planetary_positions.pluto` en el detalle) puede ser
  `null`.
- `Firmamento` (la lectura que muestra la web; usar esto y no
  `chart_data_json`, que es interno y puede cambiar de forma):
  - `motor`: versión del cálculo (hoy 2).
  - `zona`: `{timezone, desfase, rotulo, horario_verano, revisar, sugerida:
    {timezone, desfase, rotulo} | null}`.
  - `sistema_casas` (`"Placidus"`, `"Porphyry"` o `"signo entero"` en latitudes
    extremas), `cuspides` (12 longitudes, casa I primero) y `ejes`
    (`asc|mc|dsc|ic: {longitud, signo, grado_en_signo}`).
  - `cuerpos`: lista en orden de efemérides (Sol … Plutón, Quirón, Nodo Norte,
    Nodo Sur, Lilith) con `{clave, nombre, simbolo, color, longitud, signo
    (0-11), grado_en_signo, casa (1-12), retrogrado, estacionario,
    fuera_de_limites, declinacion, velocidad, dignidad: {type, modern} | null,
    es_punto}`. `dignidad.type` ∈ `domicile | exaltation | detriment | fall |
    null`; `modern: true` es la regencia moderna de Urano, Neptuno y Plutón
    (se muestra entre paréntesis). Fuera de 1800-2200 Plutón y Quirón faltan.
  - `aspectos`: `{a, b, tipo, nombre, simbolo, color, orbe, orbe_dm,
    exactitud (0-1), aplicativo, grupo: mayores | ejes | menores}`. `a` y `b`
    son claves de `cuerpos` o `asc` / `mc`.
  - `figuras`: `{tipo, etiqueta, detalle | null, cuerpos, asociados, color}`.
    `tipo` ∈ `grand_cross | t_square | angular | kite | grand_trine |
    mystic_rectangle | yod | small_grand_trine | stellium`, ya ordenadas por
    peso. `detalle` lo trae `angular` («Saturno/MC – Urano/AC»).
  - `reparto`: `{elements: {Fuego|Tierra|Aire|Agua: {weight, count, color,
    frac}}, modalities: {Cardinal|Fijo|Mutable: …}, total: 21.5}`. El
    ponderado (`weight`) es el principal y `count` el conteo simple de los 10
    planetas.
  - `luna`: `{rudhyar, elongacion, iluminacion}`; `rudhyar` ∈ `new | crescent
    | first_quarter | gibbous | full | disseminating | last_quarter |
    balsamic`.
  - `natal`: `{big_three: {sun, moon, asc} (índices de signo), chart_ruler:
    {body, modern, sign, house, dignity}, sect: {type: diurnal | nocturnal,
    luminary}, angular: [{body, angle: asc|dsc|mc|ic, distance}],
    tight_aspects (3), dominant: {element, modality}, strongest: {body,
    score, reasons, aspects}, dignities, house_rulers: {1..12: {ruler,
    modern, ruler_house, ruler_sign}}, hemispheres: {above, below, east,
    west, total}, prenatal: {lunation, eclipse_solar, eclipse_lunar}}`.
    Cada prenatal es `{type, jde, timestamp (UTC), longitude, sign, house,
    label?}` o `null`.
  - `orbes` y `clases_orbe`: la tabla de orbes por aspecto y clase de cuerpo,
    para la sección «Cómo se calculó».
- `NotaFirmamento`: `{id, contenido, es_ia, created_at}`. La lista va de la más
  nueva a la más vieja; las de la IA (`es_ia`) son largas y traen saltos de línea.
- `Consulta`: `{id, pregunta, respuesta, fuente, modelo_ia, desde_cache,
  carta_astral_id, carta_astral: {titulo, sun_degree, moon_degree, asc_degree,
  mc_degree} | null, contexto_astronomico, created_at}`. Sin IP ni lugar.
- `carta_astral` es una copia guardada con la consulta: sigue ahí aunque la
  carta se borre (entonces `carta_astral_id` es `null`).
- `contexto_astronomico` es el de la lista blanca del oráculo, sin
  `todas_las_casas` ni `zodiaco_completo`.
- El historial incluye también las consultas hechas en la web (oráculo,
  Deméter y compatibilidad), sin un campo que diga de cuál, y las respuestas
  de reserva ya devueltas (`fuente: "fallback"`).

## Observatorio y Estudios del cielo

El Observatorio tiene dos caras: **Cielos** (el clima actual de cada favorito)
y **Firmamentos** (las cartas de la sección anterior). Sobre Cielos vive el
**Estudio del cielo**: suscripción anual por favorito que captura clima y
astronomía 4 veces al día en la hora local del lugar. Se paga con polvo ya
comprado, no con Play Billing. Los precios salen siempre de `precios`; con el
cobro apagado o para admins llegan en 0. Los errores de negocio son
`422 {success: false, message}` con el mensaje listo para mostrar, y lo ajeno
responde `404`.

| Ruta | Respuesta |
|---|---|
| `GET /api/observatorio` | `{success, saldo, precios: {estudio_anual, descarga}, lugares: [{favorito_id, titulo, lat, lon, clima: {temperatura, codigo_wmo, es_de_dia, viento_kmh, humedad_pct, precipitacion_mm, reserva} \| null, estudio: Estudio \| null}], huerfanos: [Estudio]}` |
| `POST /api/favoritos/{favorito}/estudio` | Contratar · `{success, saldo, estudio}` · throttle 10/min |
| `POST /api/estudios/{estudio}/renovar` | Renovar (desde 30 días antes de vencer) · `{success, saldo, estudio}` · throttle 10/min |
| `GET /api/estudios/{estudio}` | `{success, estudio: Estudio + {lat, lon, primera_captura, ultima_captura}}` |
| `GET /api/estudios/{estudio}/resumen` | Los últimos `dias_ventana` (14) días, como el detalle web: `{success, dias_ventana, hay_clima, cobertura: {n, total, pct}, normal: {desde, hasta} \| null, kpis: {max: {v, fecha} \| null, min, lluvia: {mm, dias, aprox} \| null, presion: {delta, dir: sube\|baja\|estable, hpa} \| null}, resumen (texto listo), dias: [{fecha, n, tmax, tmin, lluvia, lluvia_aprox, pr, normal: [tmin, tmax] \| null, anomalia}]}` |
| `GET /api/estudios/{estudio}/capturas?desde&hasta&por_pagina` | `{success, capturas: [{fecha_local, turno, capturado_utc, hora_local, estacion, punto_rocio, clima \| null, astro}], paginacion: {pagina, por_pagina, total, ultima_pagina}}` (máx. 200 por página, más reciente primero) |
| `POST /api/estudios/{estudio}/exportar/{csv\|json}` | El archivo como descarga; cobra por descarga · throttle 6/min |

- `Estudio`: `{id, titulo, activo, desde, expira, renovable, capturas}`. Un
  estudio vencido queda en pausa, pero se puede leer y exportar. Uno huérfano
  (el favorito se borró) también, pero no se renueva.
- `turno` ∈ `manana | dia | tarde | noche` (07, 13, 19 y 01 h locales).
  `estacion` ∈ `primavera | verano | otono | invierno` según el hemisferio, o
  `null`.
- `clima` (compacto): `t` °C, `h` %, `n` nubosidad %, `vv` km/h, `vd` °
  (desde donde viene), `pp` mm del instante, `pr` hPa, `wmo`, `dia` (1 = de
  día), `uv` (máximo **del día**: no mostrarlo en los turnos de noche). Desde
  nov-2026 también trae `st` (sensación térmica), `vr` (ráfagas) y `p6`
  (lluvia de las 6 h previas). Las capturas viejas no los traen.
- `astro`: `{tz, off, cuerpos: {clave: {lon, sg, az, alt, sh, r, v}}, sol:
  {sal, pue, cul}, luna: {sal, pue, cul, fase, ilum}}`. Desde nov-2026 las
  capturas nuevas también traen `pluto` y `chiron` en `cuerpos`.
- La normal climatológica (`dias[].normal`, `anomalia`) la calcula un proceso
  del servidor cada hora. Para un lugar recién estudiado puede tardar en
  llegar: mientras, es `null`.

## Oráculo

| Ruta | Cuerpo | Costo |
|---|---|---|
| `POST /api/oraculo/consultar` | `{pregunta (10 a 300), nivel_contexto?: basico \| intermedio \| premium, usa_carta_astral?, carta_astral_id?, contexto_completo?}` | 5 / **10** (por defecto) / 20 ✨, **+50** con carta astral |
| `POST /api/oraculo/compatibilidad` | `{carta_a_id, carta_b_id, nivel_contexto?}` | 5 / **10** / 20 ✨ |

```json
200 { "success": true, "response": "…", "from_cache": false, "nuevo_balance": 990 }
403 { "success": false, "error": "No tienes suficiente Polvo Estelar (10 requeridos)…",
      "insufficient_coins": true, "current_balance": 4, "required_coins": 10 }
```

- `carta_astral_id` es obligatorio con `usa_carta_astral: true`. Sin
  `usa_carta_astral` (o con `false`), la carta se ignora y no se cobran los 50.
- El polvo se cobra **antes** de llamar a la IA, también cuando la respuesta
  sale de la caché (`from_cache: true`). Si la IA falla o responde con un texto
  de reserva (`fallback: true`), se devuelve solo, y `nuevo_balance` ya lo
  refleja.
- **Mirar `success` también en un 200.** `compatibilidad` puede responder 200
  `{success: false, error, nuevo_balance}` (por ejemplo si el servidor no tiene
  la clave de la IA), con el polvo ya devuelto.
- Los errores llevan el texto en `error`, no en `message`: 400 en `consultar` y
  500 en `compatibilidad`. No traen `nuevo_balance`, aunque el polvo se
  devolvió: pedir el saldo con `GET /api/me`.
- Las cartas tienen que ser del usuario: una ajena o inexistente da 422.
- Validación: `consultar` responde con la forma de Laravel, `{message, errors}`
  (una carta ajena sale en `errors.carta_astral_id`). `compatibilidad` responde
  `{success: false, error, errors}`.
- `contexto_completo` pasa por una lista blanca. Con más de 20 claves de primer
  nivel da 422. Pasan `momento`, `hemisferio`, `estacion`,
  `sol {visible, constelacion, energia}`, `luna {fase, iluminacion, influencia}`,
  `planetas_visibles` (máx. 12), `casa_dominante`, `zodiaco_dominante`,
  `todas_las_casas` y `zodiaco_completo` (máx. 12 cada uno). Los textos se
  cortan a 20-40 caracteres y pierden los saltos de línea. Lo demás se descarta.
  **No mandar coordenadas.**

## Rutas antiguas (solo la app publicada)

Siguen vivas mientras haya instalaciones de la versión actual de la Play Store.
**La app nueva no debe usarlas.**

| Ruta | Por qué no |
|---|---|
| `POST /api/login/google` con `{token}` (access token de Google) | Se acepta solo si el token es de los client IDs de la app (`GOOGLE_APP_CLIENT_IDS`); con la variable vacía da 401 «Actualiza la app para entrar con Google.». Si llegan `token` e `id_token`, manda `id_token`. La app nueva manda solo `id_token` |
| `GET /api/astronomy/map-svg-mobile`, `map-api-mobile`, `sky-data` (públicas) | El mapa va en el WebView. Además, llevan las coordenadas en la URL |
| `GET /api/astronomy/*` (con token) | Lo mismo |
| `GET /api/store/packages` sin `plataforma` · `POST /api/store/checkout` · `GET /api/store/orders/{ref}` | Mercado Pago: Google Play no lo permite para monedas virtuales en una app de Android |

Cuando la versión publicada deje de usarse, se retiran en este orden: el campo
`token` del login con Google, la tienda de Mercado Pago desde la app (la lista
sin `plataforma`, el checkout y las órdenes) y el cielo en JSON/SVG.

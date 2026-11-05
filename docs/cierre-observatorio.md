# Cierre: Firmamentos rediseñados y Observatorio

Fecha: 2026-11-04. Rama `feat/app-webview`. Prompt: `docs/prompt-app-flutter-observatorio-firmamentos.md`.

## Qué quedó

| Fase | Commit | Qué |
|---|---|---|
| 1 | `3347cfb` | Alta con la zona del lugar: sin cambio manual va **sin** `timezone` (adiós al `'UTC'` por defecto). «Cambiar zona» con un buscador IANA. El listado se llama «Firmamentos», ya no muestra datos inventados y avisa «🕐 revisar zona» |
| 2 | `91e446d` | Detalle del firmamento armado solo con `data.firmamento`, con rueda natal en `CustomPainter` (geometría y anticolisión de la web), aspectos en lista y grilla, y todas las secciones del prompt. El alta va directo al detalle |
| 3 | `d6dc9d1` | «Recalcular con {zona sugerida}»: confirmación, `PATCH …/zona` y repintado con la respuesta |
| 4 | `a69823c` | La pestaña CARTAS pasa a **OBSERVATORIO** (conmutador Cielos / Firmamentos). Cielos: clima de cada favorito, contratar y renovar el estudio, huérfanos al final |
| 5 | `ab6d96b` | Detalle del estudio: cabecera, resumen de 14 días con KPI y rango diario frente a la normal, capturas paginadas y astros por captura |
| 6 | `0f5a1dc` | Exportación CSV y JSON, entregada con la hoja de compartir (`share_plus`) y cobrada en cada descarga |

Aparte, `3a1dbd8` versiona el contrato (`docs/api-app-movil.md`) y los prompts.

## Verificación hecha

- **`flutter analyze`: 0 avisos.** **`flutter test`: 229 en verde.** Antes de este trabajo eran 191; hay 38 nuevos.
- **APK de debug compilado** con `share_plus` 13. El primer intento se cayó porque Gradle pide `-Xmx8G` y faltó RAM; el segundo compiló sin tocar nada.
- **Fixture real.** `test/fixtures/firmamento_santiago.json` se generó con el motor del servidor local, sin escribir en la base. Trae solo `firmamento`, sin datos de nacimiento.
  - Cumple todo lo esperado en la carta de ejemplo:
    - `zona.revisar` con sugerida `America/Santiago` UTC−04:00;
    - las figuras `angular` y `small_grand_trine` (con Sol y Luna asociados);
    - regente Venus en Aries, casa XII, `detriment`;
    - carta diurna, Rudhyar `last_quarter` y Marte OOB;
    - ningún aspecto Marte–Nodo Norte;
    - Luna sextil Venus a 4°45′.
  - Dos diferencias con el contrato: `natal.house_rulers` llega como **lista** (casa I primero) y `orbes` como **mapa por tipo**. El modelo acepta las dos formas.
- **Rueda y gráfico revisados a ojo.** Se renderizaron a PNG con un test temporal, ya borrado: la geometría está bien. Los glifos se ven como cuadros porque los tests usan la fuente Ahem.
- **Privacidad:**
  - `ApiClient._log` registra solo el método y la ruta, sin query, y solo en debug. Así las lat/lon de `GET /api/user/zona` no se registran.
  - Los `debugPrint` nuevos solo dan el tipo de error.
  - Ningún dato de nacimiento sale hacia otro servicio que no sea el servidor propio.
- **Colores.** Todos salen de la paleta de la app o de las tablas del prompt. Hay dos excepciones, copiadas de la rueda web que el prompt pide replicar: `#060612` (el disco de cada cuerpo) y `#7C8EA1` (los minutos bajo el glifo). Los tonos cálido, frío y normal del estudio reutilizan colores ya presentes: `#FF5D5D` de Caída, `#74C0FC` de Cáncer y `#FF9A3C` de Exilio.

## Lo que no se pudo probar (QA manual, lo hace el usuario)

Con un build nuevo en un **Android real**. El `app-release.apk` de `build/` es del 24/10 y no sirve; el `app-debug.apk` del 04/11 sí.

- [ ] **Glifos.** ♇ ⚷ ☊ ☋ ⚸ y los signos del zodiaco no deben salir como cuadro. Ya van con U+FE0E (como `ZodiacTables::asText()`). Si alguno falla, hay que decidir si se agrega una fuente; no se agregó ninguna.
- [ ] **«OBSERVATORIO» cabe en su pestaña.** Son 12 letras a 9,5 px con `letterSpacing` 0,5. Si se corta, se baja el espaciado.
- [ ] **Alta.** Crear la carta de ejemplo desde la app con la zona sugerida. Debe mostrar «America/Santiago · ese día regía UTC−04:00», y con una fecha de enero, «horario de verano».
- [ ] **Detalle.** Tomar capturas de la rueda, las posiciones, los aspectos en lista y en grilla y Dominantes. Comprobar que la rueda se lee en un teléfono pequeño y que al tocar un planeta o un aspecto se resalta.
- [ ] **Recalcular.** Hacerlo con una carta vieja en `UTC`: el ASC y las casas cambian y el distintivo «revisar zona» desaparece del listado.
- [ ] **Cielos.** Contratar con poco polvo (debe salir el mensaje del servidor) y con saldo (el saldo de la cabecera baja). Renovar un estudio a menos de 30 días de vencer.
- [ ] **Detalle del estudio.** Las etiquetas de anomalía no se enciman con 14 días en una pantalla chica, y la tabla de astros se desplaza en horizontal.
- [ ] **Exportar.** CSV y JSON: se abre la hoja de compartir con el nombre `windowsdemeter-estudio-{id}-{fecha}.{csv|json}` y el saldo baja.
- [ ] **Coherencia visual.** Comparar Firmamentos, Cielos y el estudio con Mis paisajes y Alertas. Fondos, tarjetas, tipografía, chips y glifos deben verse de la misma familia.

## Decisiones y aproximaciones a revisar

- **Fechas prenatales.** El `timestamp` UTC de la lunación y de los eclipses se pasa a hora local con el **desfase del día de nacimiento**, porque la app no tiene base de zonas. Si entre ese día y el del eclipse cambió el horario de verano, puede haber una hora de diferencia. Solo se muestra la fecha, así que afecta solo a eventos cerca de la medianoche.
- **Fondo de la rueda.** Es el color plano de la app, no el degradado radial de la web, porque el prompt prohíbe gradientes nuevos.
- **Ver el aspecto en la rueda.** Al tocar un aspecto en la lista o en la grilla se resalta en la rueda, pero la pantalla no sube hasta ella. En tablet la rueda queda a la vista; en móvil hay que subir.
- **Saldo tras exportar.** La respuesta es el archivo, sin `saldo`, así que la app pide `GET /api/me`. Si esa llamada falla, el saldo se pone al día en la próxima carga.
- **Notas y lectura IA del firmamento** (sección 11): queda el hueco. El cobro de la nota IA no se implementó, como pide el prompt.

## Textos nuevos (para la traducción)

Siguen escritos en cada pantalla, porque `docs/prompt-internacionalizacion.md` aún no se ejecutó. Al extraerlos al ARB:

- **No van al ARB.** Los textos que manda el servidor se muestran tal cual: nombres de cuerpos, aspectos y figuras, `detalle`, `resumen`, `message` y la etiqueta de fecha de los KPI.
- **Cantidades aproximadas de literales nuevos por archivo** (incluyen algunas claves técnicas):

| Archivo | Literales | Qué hay |
|---|---|---|
| `lib/screens/firmamento_detail_screen.dart` | ~106 | Secciones, subtítulos, notas al pie, aviso de zona, «Cómo se calculó» |
| `lib/screens/estudio_detail_screen.dart` | ~88 | Cabecera, KPI, leyendas, turnos, estaciones, leyenda de claves JSON, exportación |
| `lib/widgets/firmamento/tablas.dart` | ~65 | Signos, elementos, dignidades, ejes, Rudhyar, tipos de eclipse |
| `lib/screens/cielos_screen.dart` | ~37 | Tarjetas, pies de estudio, confirmaciones |
| `lib/screens/create_astral_chart_screen.dart` | ~23 | Zona del lugar, «Cambiar zona», textos de firmamento |
| `lib/screens/astral_charts_screen.dart` | ~21 | Listado y estado vacío |
| `lib/widgets/firmamento/aspectos.dart` | ~13 | Lista, Grilla, grupos, nota |
| `lib/services/*` | ~11 | Respaldos de error |
| `rueda_natal.dart`, `rango_diario.dart`, `observatorio_tab.dart` | ~11 | Rótulos y semántica |

- **Fechas y números.** Están armados a mano (`dd/mm/aaaa`, coma decimal) porque no hay `intl`. Con la internacionalización deben pasar a `DateFormat` y `NumberFormat`.
- **Nombres de producto.** «Observatorio», «Cielos», «Firmamentos» y «Estudio del cielo» siguen el glosario de la web.

## Sigue abierto, de antes

- El modo «Mapa Interactivo» del alta de firmamentos sigue sin hacer nada (`create_astral_chart_screen.dart`). Habría que quitarlo o implementarlo con lo de `docs/prompt-agregar-lugar.md`.
- Los pendientes de publicación de `docs/cierre-fase-7.md` (IDs de AdMob, SHA-1 de release, Play Console) siguen igual.

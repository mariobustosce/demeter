/// Textos de la consola de Consultas y su detalle. Son los de la web
/// (`lang/es/oraculo.php` y `comun.descargo`), copiados tal cual: si cambian
/// allí, se cambian aquí. La app no tiene i18n todavía; cuando lo tenga, este
/// archivo es el que se traduce.
abstract final class TxConsultas {
  // indice
  static const cejilla = 'Consulta CelestIAl';
  static const tituloLinea1 = 'El cielo de este momento,';
  static const tituloLinea2 = 'traducido en respuestas';
  static const lema =
      'Tres módulos sobre los mismos datos reales de este instante: Demeter para la tierra, el Oráculo para tu día y Perséfone para los vínculos. Tú eliges cuánto de ese cielo viaja al análisis.';
  static String archivo(int consultas, int firmamentos) =>
      '📚 $consultas consultas · $firmamentos firmamentos';

  // modulos
  static const moduloDemeter = '🌾 Demeter';
  static const moduloOraculo = '🔮 Oráculo';
  static const moduloPersefone = '💞 Perséfone';

  // comun
  static const eligeConsulta = 'Elige una consulta…';
  static const sinSeleccionar = 'Sin seleccionar';
  static const previewVacio = 'La pregunta elegida aparecerá aquí antes de enviarla.';
  static const resumen = 'Resumen';
  static const nivel = 'Nivel';
  static const sinElegir = 'Sin elegir';
  static const sinEspecificar = 'Sin especificar';
  static const costo = 'Costo';
  static const tokensEstimados = 'tokens estimados';
  static const consultar = 'Consultar';
  static const inteligenciaArtificial = 'Inteligencia artificial';
  static const noConfigurada = 'no configurada';
  static const notaPie = 'El costo es el mismo con cualquiera. Se descuenta sólo si responde.';
  static const limpiar = 'Limpiar';
  static const firmamentoSinTitulo = 'Firmamento sin título';

  // demeter
  static const demeterNombre = 'Demeter · el calendario de la tierra';
  static String demeterDescripcion(String lugar) =>
      'Qué sembrar, cosechar, podar o regar hoy, cruzando el clima real de $lugar con la estación y la fase lunar.';
  static const demeterPaso1Titulo = 'Profundidad del informe';
  static const demeterPaso1Pista = 'Cuántos datos de clima y pronóstico entran en el análisis.';
  static const demeterPaso2Titulo = 'Tu consulta al campo';
  static const demeterPaso2Pista = 'Preguntas de faena: siembra, cosecha, riego, poda y plagas.';
  static const demeterPaso3Titulo = 'Qué cultivas';
  static const demeterPaso3Pista = 'Opcional y sin costo extra: afina la respuesta a tu tipo de cultivo.';
  static const demeterResumenConsulta = 'Consulta';
  static const demeterResumenCultivo = 'Cultivo';
  static const demeterRespuesta = 'Informe de campo';

  // consulta (Oráculo)
  static const oraculoNombre = 'Oráculo · la lectura de tu día';
  static const oraculoDescripcion =
      'Las posiciones del cielo actual aplicadas a decisiones concretas, con o sin tu firmamento (tu carta astral).';
  static const oraculoPaso1Titulo = 'Profundidad de la lectura';
  static const oraculoPaso1Pista = 'Define cuántos datos del cielo actual viajan al análisis.';
  static const oraculoPaso2Titulo = 'Tu consulta';
  static const oraculoPaso2Pista = 'Preguntas calibradas para respuestas útiles y de costo estable.';
  static const oraculoPaso3Titulo = 'Contexto personal';
  static const oraculoPaso3Pista = 'Opcional: cruza la lectura con un firmamento guardado.';
  static const usarFirmamento = 'Usar un firmamento como contexto';
  static const usarFirmamentoDetalle = 'Añade Sol, Luna, Ascendente y Medio Cielo natales · +50 ✨';
  static const seleccionaFirmamento = 'Selecciona un firmamento…';
  static const sinFirmamentosAntes =
      'Aún no tienes firmamentos guardados. Puedes consultar igualmente con el cielo actual, o ';
  static const crearPrimerFirmamento = 'crear tu primer firmamento';
  static const sinFirmamentosDespues = ' para lecturas personalizadas.';
  static const oraculoResumenPregunta = 'Pregunta';
  static const oraculoResumenContexto = 'Contexto';
  static const cieloActual = 'Cielo actual';
  static String cieloActualMas(String nombre) => 'Cielo actual + $nombre';
  static const oraculoRespuesta = 'Visión celestial';

  // persefone
  static const persefoneNombre = 'Perséfone · el vínculo entre dos firmamentos';
  static const persefoneDescripcion =
      'Compatibilidad energética: tipo de vínculo, química, emoción y desafíos entre dos personas.';
  static const persefonePaso1Titulo = 'Profundidad del análisis';
  static const persefonePaso1Pista = 'Cuántos planetas entran en la comparación entre ambos firmamentos.';
  static const persefonePaso2Titulo = 'Los dos firmamentos';
  static const persefonePaso2Pista = 'Elige quién es quién; puedes intercambiarlas con el botón central.';
  static const personaAOpcion = 'Persona A…';
  static const personaBOpcion = 'Persona B…';
  static const intercambiar = 'Intercambiar';
  static const intercambiarAria = 'Intercambiar firmamentos';
  static const faltanFirmamentosAntes = 'Necesitas al menos dos firmamentos guardados para comparar. ';
  static const crearFirmamento = 'Crear un firmamento';
  static const persefoneResumenA = 'Persona A';
  static const persefoneResumenB = 'Persona B';
  static const lecturaRelacional = 'Lectura relacional entre dos firmamentos';
  static const persefoneBoton = 'Consulta compatibilidad';
  static const persefoneRespuesta = 'Destino revelado';
  static const cerrar = 'Cerrar';

  // historial
  static const historialTitulo = 'Historial de consultas';
  static String registros(int total) => '$total registros';
  static const leerDetalle = 'Leer detalle';
  static const nd = 'N/D';
  static const vacioCejilla = 'Historial vacío';
  static const vacioTitulo = 'Todavía no has consultado';
  static const vacioTexto =
      'Elige un módulo, un nivel y una pregunta en la consola de arriba: cada lectura quedará guardada aquí.';

  // detalle
  static const detalleTitulo = 'Detalle de consulta';
  static const moduloNombreOraculo = 'Consulta al oráculo';
  static const moduloNombreDemeter = 'Consulta a Deméter';
  static const moduloNombrePersefone = 'Consulta a Perséfone';
  static const moduloNombreNotaIa = 'Nota astrológica IA';
  static const verFirmamentoUsado = '✦ Ver el firmamento usado';
  static const preguntaTitulo = 'La pregunta';
  static String caracteres(String n) => '$n caracteres';
  static const chipCache = 'Respondida desde caché';
  static const chipFirmamento = 'Con firmamento';
  static const respuestaTitulo = 'La respuesta';
  static const parametrosTitulo = 'Parámetros';
  static const parametrosNota = 'los de esta consulta';
  static const modulo = 'Módulo';
  static const proveedor = 'Proveedor';
  static const modelo = 'Modelo';
  static const desdeCache = 'Desde caché';
  static const si = 'sí';
  static const no = 'no';
  static const tardo = 'Tardó';
  static const caracteresRotulo = 'Caracteres';
  static const guardada = 'Guardada';
  static const cieloTitulo = 'El cielo en ese momento';
  static const sinInstante = 'sin instante guardado';
  static const sobreHorizonte = 'Sobre el horizonte';
  static const bajoHorizonte = 'Bajo el horizonte';
  static const sinConstelacion = 'sin constelación guardada';
  static const energia = 'Energía';
  static const estacion = 'Estación';
  static const hemisferio = 'Hemisferio';
  static const faseNoGuardada = 'Fase no guardada';
  static String iluminada(String n) => '$n % iluminada';
  static const iluminacionNoGuardada = 'iluminación no guardada';
  static const influencia = 'Influencia';
  static const zodiacoDominante = 'Zodiaco dominante';
  static const casaDominante = 'Casa dominante';
  static const sinCielo = 'Esta consulta se guardó sin el cielo del momento.';
  static const firmamentoUsado = 'Firmamento usado';
  static String firmamentoNumero(Object id) => 'firmamento #$id';
  static const ejeSol = '☀️ Sol';
  static const ejeLuna = '🌙 Luna';
  static const ejeAc = '⬆️ AC';
  static const ejeMc = '📈 MC';
  static const verFirmamentoCompleto = 'Ver el firmamento completo →';
  static const firmamentoInterno = 'El firmamento se guardó dentro de la consulta y ya no existe por separado.';
  static const contextoTitulo = 'Contexto enviado';
  static String claves(int n) => '$n claves';
  static const vacio = 'vacío';
  static const contextoArriba = 'Todo el contexto guardado está arriba, en el cielo del momento.';
  static const sinContexto = 'La consulta viajó sin contexto astronómico.';
  static const notasTitulo = 'Mis notas';
  static const agregar = '+ Agregar';
  static const notaPlaceholder = 'Lo que quieras recordar de esta consulta… (máx. 250 caracteres)';
  static const cancelar = 'Cancelar';
  static const guardar = 'Guardar';
  static const sinNotas = 'Aún no hay notas en esta consulta.';

  // js
  static const errorGenerico = 'No se pudo completar la consulta.';
  static const desdeCacheAviso = 'Respuesta obtenida desde caché.';
  static const modoLocal = 'Respuesta obtenida en modo local.';
  static const completada = 'Consulta completada.';
  static const consultando = 'Consultando…';
  static const conectando = 'Conectando…';
  static const errorDemeter = 'No se pudo conectar con Demeter.';
  static const errorOraculo = 'No se pudo conectar con el oráculo.';
  static const errorPersefone = 'Error de conexión con Perséfone.';
  static const guardando = 'Guardando…';
  static const noSePudoGuardar = 'No se pudo guardar';

  // Propios de la app (la web no los necesita).
  static const sinSaldo = 'No te alcanza el Polvo Estelar para esta consulta.';
  static const irTienda = 'Ir a la tienda';
  static const reintentar = 'Reintentar';
  static const catalogoError = 'No se pudo cargar la consola. Revisa tu conexión.';
  static const historialError = 'No se pudo cargar el historial.';
  static const borrar = 'Eliminar';
  static String borrarPregunta(String pregunta) =>
      '¿Eliminar la consulta «$pregunta»? Esta acción no se puede deshacer.';
  static const borrada = 'Consulta eliminada exitosamente';
  static const noSeBorro = 'Error al eliminar la consulta';
  static const detalleError = 'No se pudo cargar la consulta.';

  // comun.descargo.bloque (sin el HTML) y su enlace.
  static const descargoAviso = 'Aviso:';
  static const descargoAntes =
      ' los cálculos astronómicos de Windows Demeter (posiciones, horarios, fases lunares) son datos verificables. Las interpretaciones astrológicas, en cambio, se ofrecen ';
  static const descargoFuerte = 'con fines de entretenimiento y culturales';
  static const descargoDespues =
      ': la astrología no es una ciencia y sus lecturas no están respaldadas por evidencia científica. Nada de lo que leas aquí sustituye el consejo de un profesional de la salud, legal o financiero. ';
  static const descargoEnlace = 'Leer el aviso legal completo';

  static const meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
}

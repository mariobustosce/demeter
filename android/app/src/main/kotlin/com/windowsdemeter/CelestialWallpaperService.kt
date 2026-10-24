package com.windowsdemeter

import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.service.wallpaper.WallpaperService
import android.util.Log
import android.view.SurfaceHolder
import android.view.View
import android.webkit.ConsoleMessage
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import java.util.Locale

/// El fondo animado: la página `/lively/m/{token}/{modo}` del servidor en un
/// WebView, dibujado en la superficie del fondo.
///
/// Corre en su propio proceso (`:fondo`, en el manifest): `pauseTimers()` pausa
/// todos los WebView del proceso, y en el de la app pausaría también el mapa.
/// La URL la deja la app en [FondoConfig]; cada Engine la vuelve a leer al
/// hacerse visible, así un cambio hecho en la app se ve al volver al inicio.
class CelestialWallpaperService : WallpaperService() {

    override fun onCreate() {
        super.onCreate()
        // Dos procesos no pueden compartir el directorio de datos de WebView.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                WebView.setDataDirectorySuffix("fondo")
            } catch (e: IllegalStateException) {
                // Ya había un WebView en este proceso: el sufijo ya está puesto.
            }
        }
    }

    override fun onCreateEngine(): Engine = FondoEngine()

    private enum class Carga { NADA, CARGANDO, LISTA, FALLO }

    inner class FondoEngine : Engine() {
        private val handler = Handler(Looper.getMainLooper())
        private val energia = getSystemService(PowerManager::class.java)

        private var config: FondoConfig? = null
        private var pintor: Pintor? = null
        /// Fijo para este Engine: una superficie que ya usó un productor no
        /// admite otro.
        private var tipoPintor: String? = null
        private var ancho = 0
        private var alto = 0

        /// La URL (con ratio) que tiene el WebView, y cómo va su carga.
        private var cargada: String? = null
        private var estado = Carga.NADA
        /// La superficie ya tiene un cuadro de la página: mientras carga otra,
        /// o sin red, se queda ese.
        private var hayCuadro = false
        /// El servidor dio 404: el enlace se regeneró o se borró el favorito.
        private var revocado = false
        private var despierto = false

        private var intentos = 0
        private var proximoIntento = 0L

        /// Con ahorro de energía la página anima [VENTANA_AHORRO_MS] al verse, como
        /// mucho cada [INTERVALO_AHORRO_MS], y luego queda congelada. En tiempo real:
        /// el sueño profundo también cuenta.
        private var ventanaHasta = 0L
        private var ultimaVentana = 0L

        private val reintentar = Runnable {
            cargada = null
            actualizar()
        }
        private val revisar = Runnable { actualizar() }
        /// Una carga colgada (red muy lenta, portal cautivo) cuenta como fallo.
        private val cargaLenta = Runnable { pintor?.webView?.let { falloCarga(it) } }
        private val cambioDeAhorro = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) = actualizar()
        }

        override fun onCreate(surfaceHolder: SurfaceHolder) {
            super.onCreate(surfaceHolder)
            setOffsetNotificationsEnabled(false)
            config = FondoConfig.leer(this@CelestialWallpaperService)
            val filtro = IntentFilter(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(cambioDeAhorro, filtro, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                registerReceiver(cambioDeAhorro, filtro)
            }
        }

        override fun onSurfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
            super.onSurfaceChanged(holder, format, width, height)
            if (width != ancho || height != alto) {
                ancho = width
                alto = height
                // Otro tamaño: otra pantalla virtual y otro ratio en la URL.
                liberarPintor()
            }
            actualizar()
        }

        override fun onSurfaceDestroyed(holder: SurfaceHolder) {
            super.onSurfaceDestroyed(holder)
            liberarPintor()
            hayCuadro = false
            ancho = 0
            alto = 0
        }

        override fun onVisibilityChanged(visible: Boolean) {
            if (visible) {
                val nueva = FondoConfig.leer(this@CelestialWallpaperService)
                if (nueva?.url != config?.url) {
                    // Lo eligió el usuario: se carga ya, sin esperar el backoff.
                    intentos = 0
                    proximoIntento = 0
                    revocado = false
                }
                config = nueva
            }
            actualizar()
        }

        override fun onDestroy() {
            super.onDestroy()
            unregisterReceiver(cambioDeAhorro)
            handler.removeCallbacksAndMessages(null)
            liberarPintor()
        }

        /// Pone todo de acuerdo con el estado: crea el pintor, carga la URL,
        /// dibuja o congela, y pausa o reanuda el WebView.
        private fun actualizar() {
            handler.removeCallbacks(revisar)
            if (ancho <= 0 || alto <= 0 || !surfaceHolder.surface.isValid) return
            if (!isVisible) {
                handler.removeCallbacks(reintentar)
                pintor?.congelar()
                dormir(true)
                return
            }

            val config = this.config
            val pintor = this.pintor ?: crearPintor(config) ?: return
            if (config == null) {
                pintor.mostrar(surfaceHolder, pagina = false, aviso = getString(R.string.fondo_sin_configurar))
                dormir(true)
                return
            }

            val url = conRatio(config.url)
            if (url != cargada) {
                val espera = proximoIntento - SystemClock.elapsedRealtime()
                if (espera <= 0) {
                    cargar(pintor, url)
                } else {
                    handler.removeCallbacks(reintentar)
                    handler.postDelayed(reintentar, espera)
                }
            }

            val animar = estado == Carga.LISTA && (!energia.isPowerSaveMode || enVentanaDeAhorro())
            when {
                animar -> pintor.mostrar(surfaceHolder, pagina = true, aviso = null)
                // Un mapa congelado de un lugar que ya no está engañaría.
                revocado -> pintor.mostrar(surfaceHolder, pagina = false, aviso = getString(R.string.fondo_revocado))
                hayCuadro -> pintor.congelar()
                // Sin nada que conservar: el cielo mientras carga o sin red.
                else -> pintor.mostrar(surfaceHolder, pagina = false, aviso = null)
            }
            if (animar) hayCuadro = true
            dormir(!animar && estado != Carga.CARGANDO)
        }

        private fun cargar(pintor: Pintor, url: String) {
            handler.removeCallbacks(reintentar)
            handler.removeCallbacks(cargaLenta)
            handler.postDelayed(cargaLenta, TIEMPO_CARGA_MS)
            estado = Carga.CARGANDO
            cargada = url
            pintor.webView.loadUrl(url)
        }

        /// La página cargó: se ve y anima.
        private fun paginaLista(view: WebView) {
            if (view !== pintor?.webView || estado != Carga.CARGANDO) return
            handler.removeCallbacks(cargaLenta)
            estado = Carga.LISTA
            intentos = 0
            proximoIntento = 0
            revocado = false
            // Con ahorro de energía, la página nueva también se ve un momento.
            ultimaVentana = 0
            actualizar()
        }

        /// La carga falló (sin red, 429, 503): se queda el último cuadro y se
        /// reintenta con backoff. Con [enlaceRevocado] (404) se avisa en vez
        /// de dejar el cuadro.
        private fun falloCarga(view: WebView, enlaceRevocado: Boolean = false) {
            if (view !== pintor?.webView || estado == Carga.FALLO) return
            handler.removeCallbacks(cargaLenta)
            revocado = enlaceRevocado
            estado = Carga.FALLO
            cargada = null
            programarReintento()
            actualizar()
        }

        private fun programarReintento() {
            val espera = minOf(REINTENTO_MIN_MS shl minOf(intentos, 10), REINTENTO_MAX_MS)
            intentos++
            proximoIntento = SystemClock.elapsedRealtime() + espera
            handler.removeCallbacks(reintentar)
            handler.postDelayed(reintentar, espera)
        }

        private fun enVentanaDeAhorro(): Boolean {
            val ahora = SystemClock.elapsedRealtime()
            if (ahora >= ventanaHasta) {
                if (ahora - ultimaVentana < INTERVALO_AHORRO_MS && ultimaVentana != 0L) return false
                ultimaVentana = ahora
                ventanaHasta = ahora + VENTANA_AHORRO_MS
            }
            handler.postDelayed(revisar, ventanaHasta - ahora)
            return true
        }

        /// Pausa o reanuda el WebView. Los timers son de todo el proceso:
        /// corren mientras algún Engine (el fondo o su vista previa) esté despierto.
        private fun dormir(dormido: Boolean) {
            val webView = pintor?.webView ?: return
            if (despierto == !dormido) return
            despierto = !dormido
            if (despierto) {
                despiertos.add(this)
                webView.onResume()
                webView.resumeTimers()
            } else {
                despiertos.remove(this)
                webView.onPause()
                if (despiertos.isEmpty()) webView.pauseTimers()
            }
        }

        private fun crearPintor(config: FondoConfig?): Pintor? {
            val tipo = tipoPintor ?: (config?.pintor ?: FondoConfig.PINTOR_PANTALLA).also { tipoPintor = it }
            val fps = config?.fps ?: FondoConfig.FPS_POR_DEFECTO
            val medidor = if (config?.medir == true) Medidor(tipo) else null
            val contexto = this@CelestialWallpaperService
            return try {
                val nuevo = if (tipo == FondoConfig.PINTOR_LIENZO) {
                    PintorLienzo(contexto, ancho, alto, fps, medidor, ::crearWebView)
                } else {
                    PintorPantalla(contexto, ancho, alto, fps, medidor, ::crearWebView)
                }
                // Un WebView nuevo arranca despierto, aunque otro haya pausado los timers.
                nuevo.webView.resumeTimers()
                despierto = true
                despiertos.add(this)
                pintor = nuevo
                nuevo
            } catch (e: Exception) {
                // Sin WebView (se está actualizando) o sin pantalla virtual.
                Log.w(TAG, "No se pudo crear el fondo (${e.javaClass.simpleName})")
                programarReintento()
                null
            }
        }

        private fun liberarPintor() {
            val pintor = pintor ?: return
            this.pintor = null
            handler.removeCallbacks(cargaLenta)
            despiertos.remove(this)
            despierto = false
            cargada = null
            estado = Carga.NADA
            try {
                // Si era el último despierto (la vista previa que se cierra), los
                // timers no deben seguir corriendo para el fondo oculto.
                if (despiertos.isEmpty()) pintor.webView.pauseTimers()
                pintor.liberar()
            } catch (e: Exception) {
                Log.w(TAG, "No se liberó el WebView (${e.javaClass.simpleName})")
            }
        }

        /// `?ratio=` alto ÷ ancho, en el rango que acepta el servidor. La URL
        /// del servidor no trae query: se reemplaza entera.
        private fun conRatio(url: String): String {
            val ratio = (alto.toDouble() / ancho).coerceIn(RATIO_MIN, RATIO_MAX)
            return Uri.parse(url).buildUpon()
                .clearQuery()
                .appendQueryParameter("ratio", String.format(Locale.US, "%.2f", ratio))
                .build()
                .toString()
        }

        @SuppressLint("SetJavaScriptEnabled")
        private fun crearWebView(context: Context): WebView = WebView(context).apply {
            setBackgroundColor(COLOR_CIELO)
            isVerticalScrollBarEnabled = false
            isHorizontalScrollBarEnabled = false
            overScrollMode = View.OVER_SCROLL_NEVER
            isFocusable = false
            settings.apply {
                // El mapa se anima con JS. Ningún puente JS.
                javaScriptEnabled = true
                // La página anota en sessionStorage que ya se recargó por el ratio.
                domStorageEnabled = true
                allowFileAccess = false
                allowContentAccess = false
                mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
                setGeolocationEnabled(false)
                setSupportMultipleWindows(false)
                javaScriptCanOpenWindowsAutomatically = false
                setSupportZoom(false)
            }
            webViewClient = Cliente()
            // Con un callback, Chromium no copia la consola al logcat, donde iría
            // la URL de la página (con el token).
            webChromeClient = object : WebChromeClient() {
                override fun onConsoleMessage(consoleMessage: ConsoleMessage?) = true
            }
        }

        private inner class Cliente : WebViewClient() {
            /// Solo la página del fondo, del mismo origen que la configurada. No
            /// hay navegador al que mandar lo demás: se bloquea.
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val base = config?.url?.let(Uri::parse) ?: return true
                val uri = request.url
                return !(request.isForMainFrame &&
                    uri.scheme == base.scheme &&
                    uri.host == base.host &&
                    uri.port == base.port &&
                    FondoConfig.esUrlDelFondo(uri.toString()))
            }

            override fun onPageFinished(view: WebView, url: String?) = paginaLista(view)

            override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                if (request.isForMainFrame) falloCarga(view)
            }

            override fun onReceivedHttpError(
                view: WebView,
                request: WebResourceRequest,
                errorResponse: WebResourceResponse,
            ) {
                if (request.isForMainFrame) falloCarga(view, enlaceRevocado = errorResponse.statusCode == 404)
            }

            /// Sin esto, Android cierra el proceso. Se crea otro WebView y se recarga.
            override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
                if (view === pintor?.webView) {
                    Log.w(TAG, "Se cayó el renderer del WebView")
                    liberarPintor()
                    programarReintento()
                }
                return true
            }
        }
    }

    private companion object {
        const val TAG = "FondoAnimado"
        const val RATIO_MIN = 1.5
        const val RATIO_MAX = 2.4
        const val REINTENTO_MIN_MS = 10_000L
        const val REINTENTO_MAX_MS = 30 * 60_000L
        const val TIEMPO_CARGA_MS = 60_000L
        const val VENTANA_AHORRO_MS = 5_000L
        const val INTERVALO_AHORRO_MS = 5 * 60_000L

        /// Los Engine que animan o cargan, de todo el proceso.
        val despiertos = mutableSetOf<FondoEngine>()
    }
}

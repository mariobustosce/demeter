package com.windowsdemeter

import android.app.Presentation
import android.content.Context
import android.graphics.Canvas
import android.graphics.drawable.ColorDrawable
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.hardware.display.VirtualDisplayConfig
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.util.Log
import android.util.TypedValue
import android.view.Choreographer
import android.view.Gravity
import android.view.SurfaceHolder
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.WindowManager
import android.webkit.WebView
import android.widget.FrameLayout
import android.widget.TextView
import java.util.Locale

/// El color del cielo mientras carga (el `kSkyColor` de la app) y el del aviso.
const val COLOR_CIELO = 0xFF0A0A0F.toInt()
private const val COLOR_TEXTO = 0xFF94A3B8.toInt()
private const val TAMANO_AVISO_SP = 16f
private const val MARGEN_AVISO_DP = 32

/// Cómo llega el WebView a la superficie del fondo. La fase 5 pide medir dos
/// formas antes de elegir (docs/medicion-fondo-animado.md). Cada pintor es el
/// único que dibuja en la superficie: una superficie no admite dos productores
/// (lockCanvas() y una VirtualDisplay a la vez fallan).
interface Pintor {
    val webView: WebView

    /// Dibuja en [holder]: la página si [pagina]; si no, el color del cielo con
    /// [aviso] encima, si lo hay.
    fun mostrar(holder: SurfaceHolder, pagina: Boolean, aviso: String?)

    /// Deja de dibujar: la superficie se queda con el último cuadro.
    fun congelar()

    fun liberar()
}

/// Cuenta los cuadros y escribe los fps en el logcat cada 10 s. Solo con
/// `medir` en [FondoConfig]: sin URL ni nada del usuario.
class Medidor(private val pintor: String) {
    private var cuadros = 0
    private var desde = SystemClock.elapsedRealtime()

    fun cuadro() {
        cuadros++
        val ahora = SystemClock.elapsedRealtime()
        val ms = ahora - desde
        if (ms >= 10_000) {
            Log.i(TAG, String.format(Locale.US, "pintor=%s fps=%.1f", pintor, cuadros * 1000f / ms))
            reiniciar()
        }
    }

    /// Al volver a dibujar: el tiempo congelado no cuenta.
    fun reiniciar() {
        cuadros = 0
        desde = SystemClock.elapsedRealtime()
    }

    private companion object {
        const val TAG = "FondoFps"
    }
}

/// (a) Una VirtualDisplay que compone sobre la superficie del fondo, con un
/// Presentation que tiene el WebView. El WebView está en una ventana de verdad:
/// anima y se compone por hardware. Es lo que hace Flutter con sus platform
/// views (VirtualDisplayController y SingleViewPresentation).
class PintorPantalla(
    context: Context,
    ancho: Int,
    alto: Int,
    fps: Int,
    private val medidor: Medidor?,
    crearWebView: (Context) -> WebView,
) : Pintor {
    private val pantalla: VirtualDisplay
    private val presentacion: Presentation
    private val aviso: TextView
    override val webView: WebView
    private var conectada = false

    init {
        val displays = context.getSystemService(DisplayManager::class.java)
        val dpi = context.resources.displayMetrics.densityDpi
        // Android 14+: la pantalla virtual se refresca a ese ritmo y no al de
        // la real. Antes no hay tope (ver la medición).
        pantalla = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            displays.createVirtualDisplay(
                VirtualDisplayConfig.Builder(NOMBRE, ancho, alto, dpi)
                    .setRequestedRefreshRate(fps.toFloat())
                    .build()
            )
        } else {
            displays.createVirtualDisplay(NOMBRE, ancho, alto, dpi, null, 0)
        } ?: throw IllegalStateException("Sin pantalla virtual")

        presentacion = Presentation(context, pantalla.display)
        presentacion.window?.apply {
            setType(WindowManager.LayoutParams.TYPE_PRIVATE_PRESENTATION)
            val sinFoco = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
            setFlags(sinFoco, sinFoco)
            setBackgroundDrawable(ColorDrawable(COLOR_CIELO))
        }
        val ventana = presentacion.context
        webView = crearWebView(ventana)
        aviso = TextView(ventana).apply {
            gravity = Gravity.CENTER
            setTextColor(COLOR_TEXTO)
            textSize = TAMANO_AVISO_SP
            val margen = (MARGEN_AVISO_DP * resources.displayMetrics.density).toInt()
            setPadding(margen, margen, margen, margen)
            setBackgroundColor(COLOR_CIELO)
            visibility = View.GONE
        }
        presentacion.setContentView(FrameLayout(ventana).apply {
            addView(webView, MATCH_PARENT, MATCH_PARENT)
            addView(aviso, MATCH_PARENT, MATCH_PARENT)
        })
        try {
            presentacion.show()
        } catch (e: WindowManager.InvalidDisplayException) {
            webView.destroy()
            pantalla.release()
            throw e
        }
        // Cada cuadro de la página es un cuadro de esta ventana.
        if (medidor != null) {
            presentacion.window?.addOnFrameMetricsAvailableListener(
                { _, _, _ -> medidor.cuadro() },
                Handler(Looper.getMainLooper()),
            )
        }
    }

    override fun mostrar(holder: SurfaceHolder, pagina: Boolean, aviso: String?) {
        // Oculto, el WebView también deja de animar.
        webView.visibility = if (pagina) View.VISIBLE else View.INVISIBLE
        this.aviso.text = aviso
        this.aviso.visibility = if (aviso != null) View.VISIBLE else View.GONE
        if (!conectada) {
            medidor?.reiniciar()
            pantalla.surface = holder.surface
            conectada = true
        }
    }

    override fun congelar() {
        if (!conectada) return
        // Sin superficie, la pantalla virtual se apaga y no compone más.
        pantalla.surface = null
        conectada = false
    }

    override fun liberar() {
        congelar()
        try {
            presentacion.dismiss()
        } catch (e: Exception) {
            Log.w(TAG, "No se cerró la ventana (${e.javaClass.simpleName})")
        }
        webView.destroy()
        pantalla.release()
    }

    private companion object {
        const val TAG = "PintorPantalla"
        const val NOMBRE = "fondo-animado"
    }
}

/// (b) El WebView sin ventana, dibujado con lockHardwareCanvas() a cada cuadro
/// y con el tope de fps. Puede no animar: sin ventana, Chromium puede dar la
/// página por oculta.
class PintorLienzo(
    context: Context,
    ancho: Int,
    alto: Int,
    fps: Int,
    private val medidor: Medidor?,
    crearWebView: (Context) -> WebView,
) : Pintor, Choreographer.FrameCallback {
    override val webView: WebView = crearWebView(context).apply {
        measure(
            View.MeasureSpec.makeMeasureSpec(ancho, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(alto, View.MeasureSpec.EXACTLY),
        )
        layout(0, 0, ancho, alto)
    }
    private val intervalo = 1_000_000_000L / fps.coerceIn(1, 120)
    private val densidad = context.resources.displayMetrics.density
    private val texto = TextPaint(TextPaint.ANTI_ALIAS_FLAG).apply {
        color = COLOR_TEXTO
        textSize = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_SP,
            TAMANO_AVISO_SP,
            context.resources.displayMetrics,
        )
    }
    private var holder: SurfaceHolder? = null
    private var ultimo = 0L

    override fun mostrar(holder: SurfaceHolder, pagina: Boolean, aviso: String?) {
        if (!pagina) {
            congelar()
            dibujar(holder) { canvas ->
                canvas.drawColor(COLOR_CIELO)
                if (aviso != null) pintarAviso(canvas, aviso)
            }
            return
        }
        if (this.holder != null) return
        this.holder = holder
        medidor?.reiniciar()
        Choreographer.getInstance().postFrameCallback(this)
    }

    override fun doFrame(frameTimeNanos: Long) {
        val holder = holder ?: return
        Choreographer.getInstance().postFrameCallback(this)
        // Con margen: a 60 Hz y tope de 30, se dibuja un vsync sí y otro no.
        if (frameTimeNanos - ultimo < intervalo - MARGEN_NS) return
        ultimo = frameTimeNanos
        if (dibujar(holder) { webView.draw(it) }) medidor?.cuadro()
    }

    override fun congelar() {
        holder = null
        Choreographer.getInstance().removeFrameCallback(this)
    }

    override fun liberar() {
        congelar()
        webView.destroy()
    }

    /// `false` si la superficie no se pudo bloquear (se está destruyendo).
    private inline fun dibujar(holder: SurfaceHolder, pintar: (Canvas) -> Unit): Boolean {
        val superficie = holder.surface
        val canvas = try {
            superficie.lockHardwareCanvas()
        } catch (e: Exception) {
            return false
        }
        try {
            pintar(canvas)
        } finally {
            superficie.unlockCanvasAndPost(canvas)
        }
        return true
    }

    private fun pintarAviso(canvas: Canvas, aviso: String) {
        val margen = MARGEN_AVISO_DP * densidad
        val ancho = (canvas.width - 2 * margen).toInt().coerceAtLeast(1)
        val layout = StaticLayout.Builder.obtain(aviso, 0, aviso.length, texto, ancho)
            .setAlignment(Layout.Alignment.ALIGN_CENTER)
            .build()
        canvas.save()
        canvas.translate(margen, (canvas.height - layout.height) / 2f)
        layout.draw(canvas)
        canvas.restore()
    }

    private companion object {
        const val MARGEN_NS = 4_000_000L
    }
}

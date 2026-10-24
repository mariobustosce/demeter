package com.windowsdemeter

import android.service.wallpaper.WallpaperService
import android.util.Log
import android.view.SurfaceHolder
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.renderer.FlutterRenderer
import io.flutter.plugin.common.MethodChannel

/// El fondo animado: un FlutterEngine propio (`wallpaperMain`) que dibuja en
/// la superficie del fondo.
///
/// La vista previa del selector y el fondo ya puesto son dos [Engine] que
/// comparten ese FlutterEngine, y Android no garantiza el orden entre ellos: al
/// aplicar el fondo, la vista previa se destruye después de que el fondo real
/// ya tiene su superficie. Por eso dibuja solo un Engine visible, y los demás
/// no tocan el renderer.
class CelestialWallpaperService : WallpaperService() {

    override fun onCreateEngine(): Engine = CelestialEngine()

    inner class CelestialEngine : Engine() {
        private var flutterEngine: FlutterEngine? = null
        private var channel: MethodChannel? = null

        override fun onCreate(surfaceHolder: SurfaceHolder?) {
            super.onCreate(surfaceHolder)
            val engine = FlutterEngineCache.getInstance().get(MainActivity.WALLPAPER_ENGINE_ID)
                ?: startFlutterEngine()
            flutterEngine = engine
            channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            engines.add(this)
        }

        override fun onSurfaceCreated(holder: SurfaceHolder) {
            super.onSurfaceCreated(holder)
            if (isVisible) render(holder)
        }

        override fun onSurfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
            super.onSurfaceChanged(holder, format, width, height)
            if (rendering === this) resize(width, height)
        }

        override fun onSurfaceDestroyed(holder: SurfaceHolder) {
            super.onSurfaceDestroyed(holder)
            stopRendering()
        }

        override fun onVisibilityChanged(visible: Boolean) {
            val engine = flutterEngine ?: return
            if (visible) {
                render(surfaceHolder)
                engine.lifecycleChannel.appIsResumed()
            } else if (rendering === this) {
                engine.lifecycleChannel.appIsPaused()
            }
        }

        override fun onOffsetsChanged(
            xOffset: Float,
            yOffset: Float,
            xOffsetStep: Float,
            yOffsetStep: Float,
            xPixelOffset: Int,
            yPixelOffset: Int
        ) {
            super.onOffsetsChanged(xOffset, yOffset, xOffsetStep, yOffsetStep, xPixelOffset, yPixelOffset)
            if (rendering !== this) return
            // Enviar el offset a Flutter para efectos de parallax (opcional)
            val args = mapOf("x" to xOffset, "y" to yOffset)
            channel?.invokeMethod("onOffsetsChanged", args)
        }

        override fun onDestroy() {
            super.onDestroy()
            engines.remove(this)
            stopRendering()
            // El FlutterEngine queda en caché para el próximo Engine: no se destruye.
            flutterEngine = null
        }

        /// Pasa a dibujar en la superficie de este Engine, si no lo hacía ya.
        fun render(holder: SurfaceHolder) {
            val engine = flutterEngine ?: return
            if (!holder.surface.isValid) return
            if (rendering !== this) {
                try {
                    // Suelta la superficie del Engine que dibujaba antes.
                    engine.renderer.startRenderingToSurface(holder.surface, false)
                } catch (e: Exception) {
                    Log.e(TAG, "Error al iniciar renderizado: ${e.message}")
                    return
                }
                rendering = this
            }
            val frame = holder.surfaceFrame
            resize(frame.width(), frame.height())
        }

        /// El tamaño de la superficie y el de la vista de Flutter. Sin las
        /// métricas la vista mide 0×0, el motor descarta cada cuadro y el fondo
        /// queda en negro. Los mínimos y máximos van como en FlutterView: de
        /// ellos sale el tamaño de la vista, no de width y height.
        private fun resize(width: Int, height: Int) {
            val renderer = flutterEngine?.renderer ?: return
            if (width <= 0 || height <= 0) return
            renderer.surfaceChanged(width, height)
            renderer.setViewportMetrics(FlutterRenderer.ViewportMetrics().apply {
                this.width = width
                this.height = height
                minWidth = width
                maxWidth = width
                minHeight = height
                maxHeight = height
                devicePixelRatio = resources.displayMetrics.density
            })
        }

        /// Deja de dibujar y, si otro Engine sigue a la vista, le pasa el renderer.
        private fun stopRendering() {
            if (rendering !== this) return
            rendering = null
            try {
                flutterEngine?.renderer?.stopRenderingToSurface()
            } catch (e: Exception) {
                Log.e(TAG, "Error deteniendo renderizado: ${e.message}")
            }
            engines.firstOrNull { it !== this && it.isVisible }?.let { it.render(it.surfaceHolder) }
        }
    }

    private fun startFlutterEngine(): FlutterEngine {
        // El constructor ya registra los plugins (SharedPreferences, etc.). Con
        // el contexto de la app, porque el engine sobrevive a este servicio.
        val engine = FlutterEngine(applicationContext)
        // Usar findAppBundlePath() para la ruta correcta del bundle AOT
        val flutterLoader = FlutterInjector.instance().flutterLoader()
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(flutterLoader.findAppBundlePath(), "wallpaperMain")
        )
        FlutterEngineCache.getInstance().put(MainActivity.WALLPAPER_ENGINE_ID, engine)
        return engine
    }

    companion object {
        private const val TAG = "CelestialWallpaper"
        private const val CHANNEL = "windowsdemeter.com/wallpaper"

        // De todo el proceso, como el FlutterEngine en caché.
        private val engines = mutableSetOf<CelestialEngine>()
        private var rendering: CelestialEngine? = null
    }
}

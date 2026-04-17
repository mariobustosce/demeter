package com.windowsdemeter

import android.service.wallpaper.WallpaperService
import android.view.SurfaceHolder
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.FlutterInjector
import io.flutter.plugins.GeneratedPluginRegistrant

class CelestialWallpaperService : WallpaperService() {
    
    override fun onCreateEngine(): Engine {
        return CelestialEngine()
    }

    inner class CelestialEngine : Engine() {
        private var flutterEngine: FlutterEngine? = null
        private var channel: MethodChannel? = null

        override fun onCreate(surfaceHolder: SurfaceHolder?) {
            super.onCreate(surfaceHolder)
            
            var engine = FlutterEngineCache.getInstance().get("celestial_engine")
            
            if (engine == null) {
                engine = FlutterEngine(this@CelestialWallpaperService)
                
                // Registrar plugins explícitamente (SharedPreferences, etc.)
                try {
                    GeneratedPluginRegistrant.registerWith(engine)
                } catch (e: Exception) {
                    android.util.Log.w("CelestialWallpaper", "Plugin registration: ${e.message}")
                }
                
                // Usar findAppBundlePath() para la ruta correcta del bundle AOT
                val flutterLoader = FlutterInjector.instance().flutterLoader()
                val entrypoint = DartExecutor.DartEntrypoint(
                    flutterLoader.findAppBundlePath(),
                    "wallpaperMain"
                )
                engine.dartExecutor.executeDartEntrypoint(entrypoint)
                FlutterEngineCache.getInstance().put("celestial_engine", engine)
            }
            
            flutterEngine = engine
            channel = MethodChannel(engine.dartExecutor.binaryMessenger, "windowsdemeter.com/wallpaper")
        }

        override fun onSurfaceCreated(holder: SurfaceHolder) {
            super.onSurfaceCreated(holder)
            val engine = flutterEngine ?: return
            
            // IMPORTANTE: Notificar al renderer de Flutter sobre el Surface de Android
            try {
                engine.renderer.startRenderingToSurface(holder.surface, false)
                // Sincronizar dimensiones iniciales
                val bounds = holder.surfaceFrame
                if (bounds.width() > 0 && bounds.height() > 0) {
                    engine.renderer.surfaceChanged(bounds.width(), bounds.height())
                }
            } catch (e: Exception) {
                android.util.Log.e("CelestialWallpaper", "Error al iniciar renderizado: ${e.message}")
            }
        }

        override fun onSurfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
            super.onSurfaceChanged(holder, format, width, height)
            flutterEngine?.renderer?.surfaceChanged(width, height)
        }

        override fun onSurfaceDestroyed(holder: SurfaceHolder) {
            super.onSurfaceDestroyed(holder)
            try {
                flutterEngine?.renderer?.stopRenderingToSurface()
            } catch (e: Exception) {
                android.util.Log.e("CelestialWallpaper", "Error deteniendo renderizado: ${e.message}")
            }
        }

        override fun onVisibilityChanged(visible: Boolean) {
            if (visible) {
                flutterEngine?.lifecycleChannel?.appIsResumed()
            } else {
                flutterEngine?.lifecycleChannel?.appIsPaused()
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
            // Enviar el offset a Flutter para efectos de parallax (opcional)
            val args = mapOf("x" to xOffset, "y" to yOffset)
            channel?.invokeMethod("onOffsetsChanged", args)
        }

        override fun onDestroy() {
            super.onDestroy()
            // No destruir el motor si queremos reutilizarlo en la vista previa o fondo real
            // flutterEngine?.destroy() 
            flutterEngine = null
        }
    }
}

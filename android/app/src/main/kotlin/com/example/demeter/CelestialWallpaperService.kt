package com.example.demeter

import android.service.wallpaper.WallpaperService
import android.view.SurfaceHolder
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

import android.content.Intent
import android.app.WallpaperManager
import android.content.ComponentName
import android.content.Context
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodCall

import io.flutter.embedding.engine.renderer.FlutterRenderer
import io.flutter.embedding.android.FlutterSurfaceView
import android.view.Surface

class CelestialWallpaperService : WallpaperService() {
    
    override fun onCreateEngine(): Engine {
        return CelestialEngine()
    }

    inner class CelestialEngine : Engine() {
        private var flutterEngine: FlutterEngine? = null
        private var channel: MethodChannel? = null

        override fun onCreate(surfaceHolder: SurfaceHolder?) {
            super.onCreate(surfaceHolder)
            
            // Intentar recuperar el motor del cache para evitar recrearlo innecesariamente si ya existe
            var engine = FlutterEngineCache.getInstance().get("celestial_engine")
            
            if (engine == null) {
                engine = FlutterEngine(this@CelestialWallpaperService)
                // Especificar que el punto de entrada es 'wallpaperMain'
                val entrypoint = DartExecutor.DartEntrypoint(
                    "lib/main.dart",
                    "wallpaperMain"
                )
                engine.dartExecutor.executeDartEntrypoint(entrypoint)
                FlutterEngineCache.getInstance().put("celestial_engine", engine)
            }
            
            flutterEngine = engine
            channel = MethodChannel(engine.dartExecutor.binaryMessenger, "com.example.demeter/wallpaper")
            
            // Escuchar actualizaciones desde la App principal
            channel?.setMethodCallHandler { call, result ->
                if (call.method == "updateData") {
                    // Reenviar al motor de Flutter del Wallpaper
                    channel?.invokeMethod("updateData", call.arguments)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
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
            flutterEngine?.renderer?.stopRenderingToSurface()
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

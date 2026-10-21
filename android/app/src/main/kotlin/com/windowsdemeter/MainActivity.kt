package com.windowsdemeter

import android.app.WallpaperManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Reenviamos al engine del fondo animado. Antes esto solo
                    // respondía success y los datos nunca llegaban al fondo.
                    "updateData" -> {
                        result.success(forwardToWallpaperEngine(call.method, call.arguments))
                    }
                    "openLiveWallpaperPicker" -> result.success(openLiveWallpaperPicker())
                    "isLiveWallpaperActive" -> result.success(isLiveWallpaperActive())
                    else -> result.notImplemented()
                }
            }
    }

    /// Entrega un mensaje al engine cacheado del fondo animado, si existe.
    /// Devuelve false cuando el fondo no está corriendo (nadie escucha).
    private fun forwardToWallpaperEngine(method: String, arguments: Any?): Boolean {
        val engine = FlutterEngineCache.getInstance().get(WALLPAPER_ENGINE_ID) ?: return false
        return try {
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod(method, arguments)
            true
        } catch (e: Exception) {
            Log.w(TAG, "No se pudo reenviar '$method' al fondo animado: ${e.message}")
            false
        }
    }

    /// Abre el selector de Android ya posicionado en nuestro servicio de fondo
    /// animado. Cae al selector genérico si el intent directo no existe.
    private fun openLiveWallpaperPicker(): Boolean {
        val component = ComponentName(this, CelestialWallpaperService::class.java)

        // Usamos try/catch en vez de resolveActivity: en Android 11+ la
        // visibilidad de paquetes puede ocultar el selector a la consulta
        // aunque el intent sí se pueda lanzar.
        val intents = listOf(
            Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).apply {
                putExtra(WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT, component)
            },
            Intent(WallpaperManager.ACTION_LIVE_WALLPAPER_CHOOSER),
        )

        for (intent in intents) {
            try {
                startActivity(intent)
                return true
            } catch (e: ActivityNotFoundException) {
                Log.w(TAG, "Intent no disponible (${intent.action}): ${e.message}")
            }
        }

        Log.w(TAG, "El dispositivo no expone selector de fondos animados")
        return false
    }

    private fun isLiveWallpaperActive(): Boolean {
        return try {
            val info = WallpaperManager.getInstance(this).wallpaperInfo
            info?.packageName == packageName &&
                info?.serviceName == CelestialWallpaperService::class.java.name
        } catch (e: Exception) {
            Log.w(TAG, "No se pudo leer el fondo activo: ${e.message}")
            false
        }
    }

    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "windowsdemeter.com/wallpaper"
        const val WALLPAPER_ENGINE_ID = "celestial_engine"
    }
}

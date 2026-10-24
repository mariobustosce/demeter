package com.windowsdemeter

import android.app.WallpaperManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(
                        packageManager.hasSystemFeature(PackageManager.FEATURE_LIVE_WALLPAPER)
                    )
                    "isActive" -> result.success(isLiveWallpaperActive())
                    "current" -> result.success(
                        FondoConfig.leer(this)?.let { mapOf("favorito" to it.favorito, "modo" to it.modo) }
                    )
                    "configure" -> configure(call, result)
                    "openPicker" -> result.success(openLiveWallpaperPicker())
                    else -> result.notImplemented()
                }
            }
    }

    /// Guarda lo que debe mostrar el fondo. El servicio lo lee al hacerse visible.
    private fun configure(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        val favorito = call.argument<Int>("favorito")
        val modo = call.argument<String>("modo")
        if (url == null || favorito == null || modo == null || !FondoConfig.esUrlDelFondo(url)) {
            // Sin la URL en el mensaje: lleva el token.
            result.error("argumentos", "Configuración del fondo no válida", null)
            return
        }
        val config = FondoConfig(
            url = url,
            favorito = favorito,
            modo = modo,
            pintor = call.argument<String>("pintor") ?: FondoConfig.PINTOR_PANTALLA,
            fps = call.argument<Int>("fps") ?: FondoConfig.FPS_POR_DEFECTO,
            medir = call.argument<Boolean>("medir") ?: false,
        )
        try {
            FondoConfig.guardar(this, config)
            result.success(true)
        } catch (e: Exception) {
            Log.w(TAG, "No se guardó el fondo (${e.javaClass.simpleName})")
            result.error("guardar", "No se pudo guardar el fondo", null)
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
    }
}

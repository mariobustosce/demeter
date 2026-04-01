package com.example.demeter

import android.app.WallpaperManager
import android.content.ComponentName
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.demeter/wallpaper"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openWallpaperPicker") {
                val intent = Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER)
                intent.putExtra(
                    WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
                    ComponentName(this, CelestialWallpaperService::class.java)
                )
                startActivity(intent)
                result.success(null)
            } else if (call.method == "updateData") {
                // No hacemos nada aquí, el error MissingPluginException ocurre porque 
                // este canal debe existir en ambos lados. 
                // Simplemente devolvemos éxito para que Flutter no lance la excepción.
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}

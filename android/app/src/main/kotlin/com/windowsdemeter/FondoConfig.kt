package com.windowsdemeter

import android.content.Context
import android.net.Uri
import android.util.AtomicFile
import android.util.Log
import org.json.JSONObject
import java.io.File

/// Lo que muestra el fondo animado. Lo escribe la app (MainActivity) y lo lee
/// el servicio, que corre en otro proceso: por eso es un archivo y no
/// SharedPreferences, que no se sincronizan entre procesos. Va en
/// noBackupFilesDir porque la URL lleva un token permanente.
data class FondoConfig(
    /// `/lively/m/{token}/{modo}`, sin query: el servicio le pone el ratio.
    val url: String,
    val favorito: Int,
    val modo: String,
    /// La prueba técnica de la fase 5 (docs/medicion-fondo-animado.md).
    val pintor: String = PINTOR_PANTALLA,
    val fps: Int = FPS_POR_DEFECTO,
    /// Escribe los fps en el logcat cada 10 s.
    val medir: Boolean = false,
) {
    companion object {
        private const val TAG = "FondoConfig"
        private const val ARCHIVO = "fondo_animado.json"

        /// (a) VirtualDisplay + Presentation. (b) WebView sin ventana y lockHardwareCanvas().
        const val PINTOR_PANTALLA = "pantalla"
        const val PINTOR_LIENZO = "lienzo"
        const val FPS_POR_DEFECTO = 30

        private fun archivo(context: Context) =
            AtomicFile(File(context.noBackupFilesDir, ARCHIVO))

        /// `null` sin configuración, o si el archivo no vale.
        fun leer(context: Context): FondoConfig? = try {
            val json = JSONObject(String(archivo(context).readFully(), Charsets.UTF_8))
            FondoConfig(
                url = json.getString("url"),
                favorito = json.getInt("favorito"),
                modo = json.getString("modo"),
                pintor = json.optString("pintor", PINTOR_PANTALLA),
                fps = json.optInt("fps", FPS_POR_DEFECTO),
                medir = json.optBoolean("medir", false),
            ).takeIf { esUrlDelFondo(it.url) }
        } catch (e: java.io.FileNotFoundException) {
            null
        } catch (e: Exception) {
            Log.w(TAG, "Configuración ilegible (${e.javaClass.simpleName})")
            null
        }

        fun guardar(context: Context, config: FondoConfig) {
            val json = JSONObject()
                .put("url", config.url)
                .put("favorito", config.favorito)
                .put("modo", config.modo)
                .put("pintor", config.pintor)
                .put("fps", config.fps)
                .put("medir", config.medir)
            val archivo = archivo(context)
            val salida = archivo.startWrite()
            try {
                salida.write(json.toString().toByteArray(Charsets.UTF_8))
                archivo.finishWrite(salida)
            } catch (e: Exception) {
                archivo.failWrite(salida)
                throw e
            }
        }

        /// Solo la página del fondo: `http(s)://host/lively/m/…`. El cleartext
        /// lo bloquea network_security_config fuera de debug.
        fun esUrlDelFondo(url: String): Boolean {
            val uri = Uri.parse(url)
            return (uri.scheme == "https" || uri.scheme == "http") &&
                !uri.host.isNullOrEmpty() &&
                uri.userInfo == null &&
                uri.path?.startsWith("/lively/m/") == true &&
                uri.pathSegments.none { it == ".." || it == "." }
        }
    }
}

# Demeter - Oráculo Celestial 🌌

Demeter es una aplicación de astrología y astronomía en tiempo real que utiliza un motor de renderizado personalizado (Canvas) para mostrar el cielo exacto según tu ubicación geográfica y el tiempo.

## 🚀 Funcionalidades Principales

- **Mapa Celestial Dinámico:** Visualización interactiva de planetas, constelaciones, casas astrológicas y eventos solares/lunares.
- **Canvas Engine:** Motor gráfico propio basado en `CustomPainter` que traduce datos JSON astronómicos en arte visual fluido.
- **Consultas al Oráculo:** Interacción con servicios de interpretación astral.
- **Protector de Pantalla (Screen Saver):** Modo inmersivo que utiliza el motor de renderizado para transformar tu dispositivo en una ventana al cosmos con animaciones de titileo (twinkle) en tiempo real.

## 📱 Live Wallpaper Engine (En Desarrollo)

Estamos implementando una arquitectura avanzada para permitir que el cielo de Demeter sea tu fondo de pantalla real en Android:

### Arquitectura Nativa
- **Android `WallpaperService`:** Un servicio nativo en Kotlin ([CelestialWallpaperService.kt](android/app/src/main/kotlin/com/example/demeter/CelestialWallpaperService.kt)) que permite al sistema Android registrar la aplicación como un fondo de pantalla animado.
- **Flutter Background Engine:** El servicio levanta un motor de Flutter independiente para renderizar el `CelestialPainter` incluso cuando la aplicación principal está cerrada.
- **Sincronización:** Los colores del cielo y la posición de los astros se actualizan automáticamente al detectar cambios en el estado del dispositivo (desbloqueo o paso del tiempo).

### Cómo usar como Fondo de Pantalla (Próximamente)
1. Ve a los ajustes de Fondo de Pantalla de tu dispositivo Android.
2. Selecciona "Fondos de pantalla animados".
3. Elige **"Demeter Celestial"**.

## 🛠️ Tecnologías

- **Flutter & Dart:** UI y motor de renderizado multiplataforma.
- **Kotlin (Android):** Servicios de sistema para fondos de pantalla animados.
- **Sky API:** Integración de datos astronómicos precisos.

---
*Desarrollado con precisión celestial.*

## 🛠️ Corrección de Errores e Historial de Cambios
- **Actualización de Versión de iOS:** Se corrigió un error de compilación con Cocoapods (workmanager_apple requires a higher minimum deployment target). Se actualizó IPHONEOS_DEPLOYMENT_TARGET a la versión 14.0 en ios/Runner.xcodeproj/project.pbxproj.

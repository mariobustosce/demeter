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
- **Mapa SVG Expandible con Snap-back:** Se añadió interactividad al mapa celestial en `HomeScreenV2` usando `InteractiveViewer`. Ahora el usuario puede hacer zoom y paneo libremente, pero al soltar, el mapa regresa automáticamente a su tamaño y posición original mediante una animación suave (`TransformationController` y `AnimationController`).
- **Publicidad AdMob Básica:** Se integró un **BannerAd** en `lib/screens/home_screen_v2.dart` y se configuró el SDK de AdMob en `lib/main.dart` con `MobileAds.instance.initialize()`. Además se agregó el `AdMob App ID` en `android/app/src/main/AndroidManifest.xml` para habilitar anuncios en Android.
- **InterstitialAd en Consultas y Compatibilidad:** Se implementó un **InterstitialAd** en `lib/screens/new_consultation_screen.dart` y en `lib/screens/compatibility_screen.dart`. El anuncio se carga en `initState()`, se muestra antes de la acción principal, y se vuelve a crear después de cerrarse.
- **Actualización de Versión de iOS:** Se corrigió un error de compilación con Cocoapods (workmanager_apple requires a higher minimum deployment target). Se actualizó IPHONEOS_DEPLOYMENT_TARGET a la versión 14.0 en ios/Runner.xcodeproj/project.pbxproj.

## 📈 Próximo paso: RewardedAd (V2)

Para la siguiente versión, cuando tengamos más usuarios y queramos monetizar mejor, podemos agregar un `RewardedAd` en lugar de o además del interstitial. Los pasos serían:

1. **Agregar o reutilizar la dependencia** `google_mobile_ads` en `pubspec.yaml` (ya está instalada).
2. **Crear un `RewardedAd`** en las pantallas donde quieras ofrecer beneficio al usuario, por ejemplo en:
   - `lib/screens/new_consultation_screen.dart`
   - `lib/screens/compatibility_screen.dart`
3. **Configurar el ID de prueba** de AdMob para desarrollo:
   ```dart
   adUnitId: 'ca-app-pub-3940256099942544/5224354917'
   ```
4. **Cargar el anuncio** en `initState()` y manejar los callbacks:
   - `onAdLoaded`
   - `onAdFailedToLoad`
   - `onUserEarnedReward`
   - `onAdDismissedFullScreenContent`
5. **Mostrar el anuncio** cuando el usuario ejecute una acción premium, y solo avanzar cuando el ad termine o falle.
6. **Recompensar al usuario** en `onUserEarnedReward()` con algo valioso dentro de la app (por ejemplo: acceso a contenido premium, descontar costo de consulta, más “Polvo Estelar”, etc.).
7. **Reemplazar los IDs de prueba** por los reales de AdMob antes de publicar la actualización.

> Nota: `RewardedAd` generalmente paga más que un banner o un interstitial, pero debe ofrecer un valor real al usuario para que el modelo tenga sentido.

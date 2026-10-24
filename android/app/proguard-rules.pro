-dontwarn org.conscrypt.**
-keep class org.conscrypt.** { *; }

# flutter_local_notifications usa Gson por reflexión; con R8 full mode hay que
# conservar los TypeToken o las notificaciones fallan en release.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
